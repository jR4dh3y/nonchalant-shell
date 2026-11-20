.pragma library

function localPath(url) {
    return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
}

function type(path) {
    const extension = path.toLowerCase().split(".").pop();
    if (["jpg", "jpeg", "png", "tif", "tiff", "bmp"].includes(extension))
        return "image";
    if (extension === "gif")
        return "gif";
    if (extension === "webp" || extension === "avif")
        return "web-image";
    if (["mp4", "webm", "mov", "avi", "mkv"].includes(extension))
        return "video";
    return "";
}

function needsFrame(path) {
    const kind = type(path);
    return kind === "gif" || kind === "video" || kind === "web-image";
}

function framePath(path, cacheDir) {
    if (needsFrame(path))
        return cacheDir + "/lockscreen/" + Qt.md5(path) + ".jpg";
    return path;
}

function frameUrl(path, cacheDir, revisions) {
    if (!path)
        return "";
    const frame = framePath(path, cacheDir);
    return "file://" + frame + (frame === path ? "" : "?r=" + (revisions[frame] ?? 0));
}
