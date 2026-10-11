pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant

Singleton {
    readonly property bool available: Nonchalant.GithubService.available
    readonly property list<var> weeks: Nonchalant.GithubService.weeks
    readonly property string user: Nonchalant.GithubService.user
    readonly property int total: Nonchalant.GithubService.total
    readonly property int streak: Nonchalant.GithubService.streak
    readonly property int today: Nonchalant.GithubService.today
    readonly property int busiest: Nonchalant.GithubService.busiest
    readonly property string age: Nonchalant.GithubService.age
    readonly property string totalLabel: Nonchalant.GithubService.totalLabel
    readonly property int cardGrid: 7 * 9 + 6 * 3

    function subscribe(): void { Nonchalant.GithubService.subscribe() }
    function release(): void { Nonchalant.GithubService.release() }
    function refresh(): void { Nonchalant.GithubService.refresh() }
    function grouped(count: int): string { return Nonchalant.GithubService.grouped(count) }
}
