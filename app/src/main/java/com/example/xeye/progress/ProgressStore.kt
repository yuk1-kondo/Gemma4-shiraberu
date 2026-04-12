package com.example.xeye.progress

import android.content.Context

class ProgressStore(context: Context) {

    private val prefs = context.getSharedPreferences("progress", Context.MODE_PRIVATE)

    var playerName: String
        get() = prefs.getString("player_name", "") ?: ""
        set(value) { prefs.edit().putString("player_name", value).commit() }

    var totalExamined: Int
        get() = prefs.getInt("total_examined", 0)
        set(value) { prefs.edit().putInt("total_examined", value).commit() }

    var totalXp: Long
        get() = prefs.getLong("total_xp", 0L)
        private set(value) { prefs.edit().putLong("total_xp", value).commit() }

    var maxCombo: Int
        get() = prefs.getInt("max_combo", 0)
        set(value) { prefs.edit().putInt("max_combo", value).commit() }

    val level: Int get() {
        var lv = MAX_LEVEL
        while (lv > 1 && totalXp < xpForLevel(lv)) lv--
        return lv
    }

    val currentLevelXp: Int get() = (totalXp - xpForLevel(level)).toInt()

    val xpToNextLevel: Int get() {
        if (level >= MAX_LEVEL) return 0
        return (xpForLevel(level + 1) - xpForLevel(level)).toInt()
    }

    val levelTitle: String get() = LEVEL_TITLES.getOrElse(level - 1) { "万物を見通す者" }

    val isMaxLevel: Boolean get() = level >= MAX_LEVEL

    fun addXp(amount: Int): Boolean {
        val oldLevel = level
        totalExamined++
        totalXp += amount
        return level > oldLevel
    }

    private fun xpForLevel(level: Int): Long {
        if (level <= 1) return 0
        val n = level.toLong()
        return 100L * n * n * n
    }

    companion object {
        const val MAX_LEVEL = 99
        const val XP_PER_EXAMINE = 15

        val LEVEL_TITLES = listOf(
            // Lv.1-10: 見習い時代
            "鑑定見習い",
            "駆け出し鑑定士",
            "初級鑑定士",
            "中級鑑定士",
            "上級鑑定士",
            "特級鑑定士",
            "鑑定師",
            "優秀な鑑定師",
            "精鋭鑑定師",
            "大鑑定師",
            // Lv.11-20: 鑑定の騎士団
            "鑑定の騎士",
            "鑑定の兵長",
            "鑑定の百騎長",
            "鑑定の千騎長",
            "鑑定の騎士団長",
            "鑑定の近衛騎士",
            "鑑定の聖騎士",
            "鑑定の勇者",
            "鑑定の英雄",
            "鑑定の覇王",
            // Lv.21-30: 鑑定の術師
            "鑑定の術師",
            "鑑定の魔術師",
            "鑑定の魔法使い",
            "鑑定の賢者",
            "鑑定の大賢者",
            "鑑定の司書",
            "鑑定の大司書",
            "鑑定の学者",
            "鑑定の大博士",
            "鑑定の権威",
            // Lv.31-40: 鑑定の達人
            "鑑定の名人",
            "鑑定の達人",
            "鑑定の宗匠",
            "鑑定の大家",
            "万物の鑑定師",
            "真理の鑑定師",
            "深淵の鑑定師",
            "星空の鑑定師",
            "次元の鑑定師",
            "永遠の鑑定師",
            // Lv.41-50: 聖なる鑑定
            "聖鑑定師",
            "神官鑑定師",
            "大神官鑑定師",
            "天界の鑑定師",
            "天界の大鑑定師",
            "星屑の鑑定師",
            "流星の鑑定師",
            "彗星の鑑定師",
            "銀河の鑑定師",
            "宇宙の鑑定師",
            // Lv.51-60: 伝説へ
            "伝説の鑑定士",
            "神話の鑑定士",
            "太古の鑑定士",
            "始原の鑑定士",
            "創世の鑑定士",
            "天地の鑑定士",
            "日月の鑑定士",
            "陰陽の鑑定士",
            "虚空の鑑定士",
            "無限の鑑定士",
            // Lv.61-70: 神域
            "神の鑑定使",
            "神の鑑定師",
            "天神の鑑定師",
            "龍神の鑑定師",
            "魔神の鑑定師",
            "界王の鑑定師",
            "大界王の鑑定師",
            "星王の鑑定師",
            "銀王の鑑定師",
            "金王の鑑定師",
            // Lv.71-80: 至高
            "至高の鑑定士",
            "絶対の鑑定士",
            "無双の鑑定士",
            "不滅の鑑定士",
            "永劫の鑑定士",
            "輪廻の鑑定士",
            "超越の鑑定士",
            "究極の鑑定士",
            "至聖の鑑定士",
            "無限超越の鑑定士",
            // Lv.81-90: 不可思議
            "不可思議の鑑定者",
            "奇跡の鑑定者",
            "幻想の鑑定者",
            "夢幻の鑑定者",
            "幻影の鑑定者",
            "真幻の鑑定者",
            "虚無の鑑定者",
            "混沌の鑑定者",
            "渾沌の鑑定者",
            "太虚の鑑定者",
            // Lv.91-99: 神
            "半神の鑑定者",
            "神人の鑑定者",
            "天神の鑑定者",
            "大天使の鑑定者",
            "神王の鑑定者",
            "創造神の鑑定者",
            "破壊神の鑑定者",
            "万物神の鑑定者",
            "全知全能の鑑定神",
        )
    }
}
