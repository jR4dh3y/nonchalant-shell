pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    component Notif: QtObject {
        required property int id
        property Notification notification
        property list<var> actions: notification?.actions.map(action => ({
                    "identifier": action.identifier,
                    "text": action.text
                })) ?? []
        property bool popup: false
        // Capturar valores inmediatamente para evitar binding issues
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string image: ""
        property string summary: ""
        property double time
        property string urgency: "normal"
        property int historyPriority: 0
        property string replaceKey: ""
        property var localActionHandlers: ({})
        property Timer timer

        // Propiedades para cache de imágenes
        property string cachedAppIcon: ""
        property string cachedImage: ""

        // Indica si esta notificación fue cargada desde cache
        property bool isCached: false

        // Inicializar valores cuando se asigna la notification
        onNotificationChanged: {
            if (notification) {
                appIcon = notification.appIcon ?? "";
                appName = notification.appName ?? "";
                body = notification.body ?? "";
                image = notification.image ?? "";
                summary = notification.summary ?? "";
                urgency = notification.urgency.toString() ?? "normal";

                // Cachear imágenes
                if (appIcon && !appIcon.startsWith("data:")) {
                    root.cacheImageAsBase64(appIcon, function (cachedData) {
                        cachedAppIcon = cachedData;
                    });
                }
                if (image && !image.startsWith("data:")) {
                    root.cacheImageAsBase64(image, function (cachedData) {
                        cachedImage = cachedData;
                    });
                }

                // Escuchar cuando la notificación es cerrada por la aplicación
                notification.closed.connect(function (reason) {
                    // CloseRequested = 3: la aplicación solicitó cerrar la notificación
                    if (reason === 3) {
                        root.discardNotification(id);
                    }
                });
            }
        }

        Component.onDestruction: {
            if (timer) {
                timer.stop();
                timer.destroy();
                timer = null;
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "id": notif.id,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
            "historyPriority": notif.historyPriority,
            "replaceKey": notif.replaceKey,
            "cachedAppIcon": notif.cachedAppIcon,
            "cachedImage": notif.cachedImage,
            "isCached": notif.isCached
        };
    }

    component NotifTimer: Timer {
        required property int id
        property bool isPaused: false
        property real startTime: Date.now()

        property var suspendConnections: Connections {
            target: SuspendManager
            function onWakingUp() {
                if (!isPaused) {
                    // Small delay after wake to prevent popups appearing while screen is still transitioning
                    wakeStartTimer.restart();
                }
            }
        }

        property var wakeStartTimer: Timer {
            id: wakeStartTimer
            interval: 1000
            repeat: false
            onTriggered: if (!isPaused)
                parent.start()
        }

        running: !isPaused && !SuspendManager.isSuspending && interval > 0
        onTriggered: root.timeoutNotification(id)

        function pause() {
            isPaused = true;
            stop();
        }

        function resume() {
            isPaused = false;
            if (!SuspendManager.isSuspending && interval > 0) {
                start();
            }
        }
    }

    property bool silent: false
    property list<Notif> list: []
    // Explicit list reassigned in rebuildGroups so toast ListViews rebind.
    property var popupList: []
    property bool popupInhibited: silent
    property var latestTimeForApp: ({})
    property var totalCounts: ({})  // Conteo total independiente del almacenamiento: {appName: {summary: count}}

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    FileView {
        id: notifFileView
        // QUICKSHELL-GIT: path: Quickshell.cachePath("notifications.json")
        path: Quickshell.env("HOME") + "/.cache/nonchalant/notifications.json"
        onLoaded: loadNotifications()
    }

    function stringifyList(list) {
        return JSON.stringify(list.map(notif => notifToJSON(notif)), null, 2);
    }

    function jsonToNotif(json) {
        return notifComponent.createObject(root, {
            "id": json.id,
            "actions": json.actions,
            "appIcon": json.cachedAppIcon || json.appIcon  // Usar cached si disponible
            ,
            "appName": json.appName,
            "body": json.body,
            "image": json.cachedImage || json.image  // Usar cached si disponible
            ,
            "summary": json.summary,
            "time": json.time,
            "urgency": json.urgency,
            "historyPriority": json.historyPriority || 0,
            "replaceKey": json.replaceKey || "",
            "cachedAppIcon": json.cachedAppIcon || "",
            "cachedImage": json.cachedImage || "",
            "isCached": json.isCached || true  // Default to true for loaded notifications
            ,
            "popup": false  // No popup para notificaciones cargadas
        });
    }

    function saveNotifications() {
        // Limitar notificaciones almacenadas a 5 por summary para evitar almacenamiento excesivo
        const limitedList = limitNotificationsPerSummary(root.list);
        notifFileView.setText(stringifyList(limitedList));
    }

    function limitNotificationsPerSummary(notifications) {
        var groups = {};

        notifications.forEach(notif => {
            const key = notif.appName + '|' + (notif.summary || '');
            if (!groups[key]) {
                groups[key] = [];
            }
            groups[key].push(notif);
        });

        const limitedNotifications = [];
        for (const key in groups) {
            const group = groups[key];
            group.sort((a, b) => b.time - a.time);
            limitedNotifications.push(...group.slice(0, 5));
        }

        return limitedNotifications;
    }

    function loadNotifications() {
        try {
            const data = JSON.parse(notifFileView.text());
            root.list = data.map(jsonToNotif);
            // Set idOffset to max id + 1
            let maxId = 0;
            root.list.forEach(notif => {
                if (notif.id > maxId)
                    maxId = notif.id;
                if (notif.id <= -1000000)
                    root.internalIdCounter = Math.max(root.internalIdCounter, Math.abs(notif.id) - 999999);
            });
            root.idOffset = maxId + 1;
        } catch (e) {
            console.log("No saved notifications or error loading:", e);
            root.list = [];
            root.idOffset = 0;
        }
        rebuildGroups();
    }

    onListChanged: {
        // Update latest time for each app
        root.list.forEach(notif => {
            if (!root.latestTimeForApp[notif.appName] || notif.time > root.latestTimeForApp[notif.appName]) {
                root.latestTimeForApp[notif.appName] = Math.max(root.latestTimeForApp[notif.appName] || 0, notif.time);
            }
        });
        // Remove apps that no longer have notifications
        Object.keys(root.latestTimeForApp).forEach(appName => {
            if (!root.list.some(notif => notif.appName === appName)) {
                delete root.latestTimeForApp[appName];
            }
        });
        rebuildGroups();
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            if (groups[b].historyPriority !== groups[a].historyPriority) {
                return groups[b].historyPriority - groups[a].historyPriority;
            }
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif, index) => {
            // Verificar que la notificación es válida antes de agruparla
            if (!notif || !notif.appName || (!notif.summary && !notif.body)) {
                return;
            }

            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    historyPriority: 0,
                    totalCount: 0  // Conteo independiente del almacenamiento
                };
            }
            groups[notif.appName].notifications.push(notif);
            groups[notif.appName].totalCount++;
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
            groups[notif.appName].historyPriority = Math.max(groups[notif.appName].historyPriority || 0, notif.historyPriority || 0);
        });

        return groups;
    }

    // Explicit props so ListViews rebind reliably when the history list mutates.
    property var groupsByAppName: ({})
    property var popupGroupsByAppName: ({})
    property var appNameList: []
    property var popupAppNameList: []

    function rebuildGroups() {
        // Fresh array each time so QML property notifiers fire for toast windows.
        popupList = root.list.filter(notif => notif && notif.popup === true);
        groupsByAppName = groupsForList(root.list);
        popupGroupsByAppName = groupsForList(popupList);
        appNameList = appNameListForGroups(groupsByAppName);
        popupAppNameList = appNameListForGroups(popupGroupsByAppName);
    }

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    property int internalIdCounter: 1
    signal initDone
    signal notify(notification: var)
    signal discard(id: var)
    signal discardAll
    signal timeout(id: var)

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            // Verificar que la notificación tiene contenido válido antes de procesarla
            if (!notification || (!notification.summary && !notification.body)) {
                return;
            }

            notification.tracked = true;
            const newNotifObject = notifComponent.createObject(root, {
                "id": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now()
            });

            // Usar Qt.callLater para evitar race conditions al actualizar la lista
            Qt.callLater(() => {
                root.list = [...root.list, newNotifObject];
                saveNotifications();
            });

            // Queue transient notification data for interested views.
            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                    "id": newNotifObject.id,
                    "interval": notification.expireTimeout < 0 ? 5000 : notification.expireTimeout
                });
            }

            root.notify(newNotifObject);
        }
    }

    function notifyInternal(options) {
        if (!options || (!options.summary && !options.body)) {
            return null;
        }

        if (options.replaceKey) {
            const existingIds = root.list.filter(notif => notif && notif.replaceKey === options.replaceKey).map(notif => notif.id);
            if (existingIds.length > 0) {
                root.discardNotifications(existingIds);
            }
        }

        const notificationId = -1000000 - root.internalIdCounter++;
        const newNotifObject = notifComponent.createObject(root, {
            "id": notificationId,
            "actions": options.actions || [],
            "appIcon": options.appIcon || "",
            "appName": options.appName || "Nonchalant",
            "body": options.body || "",
            "image": options.image || "",
            "summary": options.summary || "",
            "time": options.time || Date.now(),
            "urgency": options.urgency || NotificationUrgency.Normal,
            "historyPriority": options.historyPriority || 0,
            "replaceKey": options.replaceKey || "",
            "localActionHandlers": options.actionHandlers || {},
            "popup": !root.popupInhibited && options.popup !== false,
            "isCached": false
        });

        if (newNotifObject.popup) {
            newNotifObject.timer = notifTimerComponent.createObject(root, {
                "id": newNotifObject.id,
                "interval": options.expireTimeout || 5000
            });
        }

        root.list = [...root.list, newNotifObject];
        saveNotifications();
        root.notify(newNotifObject);
        return newNotifObject;
    }

    function discardNotification(id) {
        const index = root.list.findIndex(notif => notif.id === id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
        if (index !== -1) {
            root.list.splice(index, 1);
            triggerListChange();
            saveNotifications();
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss();
        }
        root.discard(id);
    }

    function discardNotifications(ids) {
        if (!ids || ids.length === 0)
            return;

        var idsMap = {};
        ids.forEach(id => {
            idsMap[id] = true;
        });

        const newList = root.list.filter(notif => !idsMap[notif.id]);
        const removedCount = root.list.length - newList.length;

        if (removedCount > 0) {
            root.list = newList;
            triggerListChange();
            saveNotifications();
        }

        ids.forEach(id => {
            const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
            if (notifServerIndex !== -1) {
                notifServer.trackedNotifications.values[notifServerIndex].dismiss();
            }
            root.discard(id);
        });
    }

    function discardAllNotifications() {
        root.list = [];
        triggerListChange();
        saveNotifications();
        notifServer.trackedNotifications.values.forEach(notif => {
            notif.dismiss();
        });
        root.discardAll();
    }

    signal timeoutWithAnimation(id: var)

    Timer {
        id: timeoutAnimationTimer
        interval: 350
        running: false
        repeat: false
        property int notificationId: -1
        onTriggered: {
            const index = root.list.findIndex(notif => notif.id === notificationId);
            if (index !== -1 && root.list[index] != null)
                root.list[index].popup = false;
            // Re-emit list so popupList / toast window rebind.
            triggerListChange();
            root.timeout(notificationId);
        }
    }

    function timeoutNotification(id) {
        // Immediate dismiss for this id (X button / expire). Avoid the single
        // shared animation timer which could only clear one id at a time.
        clearPopupById(id);
    }

    function stopNotifTimer(notif) {
        if (!notif || !notif.timer)
            return;
        try {
            notif.timer.stop();
            notif.timer.destroy();
        } catch (e) {}
        notif.timer = null;
    }

    function clearPopupById(id) {
        const targetId = Number(id);
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            const notif = root.list[i];
            if (!notif || Number(notif.id) !== targetId)
                continue;
            stopNotifTimer(notif);
            if (notif.popup) {
                notif.popup = false;
                changed = true;
            }
            root.timeout(notif.id);
            break;
        }
        if (changed)
            forcePopupRefresh();
    }

    // Drop every live toast for an app name (X on a grouped toast).
    function dismissPopupApp(appName) {
        const name = String(appName || "");
        if (!name)
            return;
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            const notif = root.list[i];
            if (!notif || !notif.popup)
                continue;
            if (String(notif.appName) !== name)
                continue;
            stopNotifTimer(notif);
            notif.popup = false;
            root.timeout(notif.id);
            changed = true;
        }
        if (changed)
            forcePopupRefresh();
    }

    // Hide every live toast regardless of app.
    function dismissAllPopups() {
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            const notif = root.list[i];
            if (!notif || !notif.popup)
                continue;
            stopNotifTimer(notif);
            notif.popup = false;
            root.timeout(notif.id);
            changed = true;
        }
        if (changed)
            forcePopupRefresh();
    }

    function timeoutAll() {
        dismissAllPopups();
    }

    // Always rebuild popup arrays from scratch and reassign so QML bindings fire.
    function forcePopupRefresh() {
        const next = [];
        for (let i = 0; i < root.list.length; i++)
            next.push(root.list[i]);
        root.list = next;
        rebuildGroups();
    }

    function attemptInvokeAction(id, notifIdentifier, autoDiscard = true) {
        const notifIndex = root.list.findIndex(notif => notif.id === id);
        if (notifIndex !== -1) {
            const localHandlers = root.list[notifIndex].localActionHandlers || {};
            const localHandler = localHandlers[notifIdentifier];
            if (typeof localHandler === "function") {
                localHandler(id);
            }
        }

        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find(action => action.identifier === notifIdentifier);
            if (action) {
                action.invoke();
            }
        }
        if (autoDiscard) {
            root.discardNotification(id);
        }
    }

    function pauseGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function pauseAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function hideAllPopups() {
        dismissAllPopups();
    }

    IpcHandler {
        target: "notifications"

        function dismissAll() {
            root.dismissAllPopups();
        }

        function dismissApp(appName: string) {
            root.dismissPopupApp(appName);
        }
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    property int activeXhrCount: 0
    property int maxConcurrentXhr: 3

    function cacheImageAsBase64(imageUrl, callback) {
        if (!imageUrl || imageUrl.startsWith("data:")) {
            callback(imageUrl);
            return;
        }

        if (!imageUrl.startsWith("http://") && !imageUrl.startsWith("https://")) {
            callback(imageUrl);
            return;
        }

        if (imageUrl.length > 2048) {
            callback(imageUrl);
            return;
        }

        if (activeXhrCount >= maxConcurrentXhr) {
            callback(imageUrl);
            return;
        }

        activeXhrCount++;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", imageUrl, true);
        xhr.responseType = "arraybuffer";
        xhr.timeout = 5000;

        var cleanupXhr = function () {
            activeXhrCount--;
            xhr = null;
        };

        xhr.onload = function () {
            if (xhr.status === 200 && xhr.response) {
                try {
                    var arrayBuffer = xhr.response;
                    var bytes = new Uint8Array(arrayBuffer);
                    var binary = '';
                    var len = Math.min(bytes.byteLength, 1024 * 1024);
                    for (var i = 0; i < len; i++) {
                        binary += String.fromCharCode(bytes[i]);
                    }
                    var base64 = btoa(binary);

                    var mimeType = "image/png";
                    var lowerUrl = imageUrl.toLowerCase();
                    if (lowerUrl.includes(".jpg") || lowerUrl.includes(".jpeg")) {
                        mimeType = "image/jpeg";
                    } else if (lowerUrl.includes(".gif")) {
                        mimeType = "image/gif";
                    } else if (lowerUrl.includes(".webp")) {
                        mimeType = "image/webp";
                    }

                    callback("data:" + mimeType + ";base64," + base64);
                } catch (e) {
                    callback(imageUrl);
                }
            } else {
                callback(imageUrl);
            }
            cleanupXhr();
        };

        xhr.onerror = function () {
            callback(imageUrl);
            cleanupXhr();
        };

        xhr.ontimeout = function () {
            callback(imageUrl);
            cleanupXhr();
        };

        xhr.send();
    }

    Component.onCompleted: {
        // History groups must exist before FileView finishes; then load disk cache.
        rebuildGroups();
        notifFileView.reload();
        root.initDone();
    }
}
