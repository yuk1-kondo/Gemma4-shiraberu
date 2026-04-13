package com.example.xeye.progress

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

// ========== Screen Navigation ==========

enum class GameScreen {
    CAMERA, COLLECTION, DIARY, QUESTS, ACHIEVEMENTS, MENU
}

// ========== Data Models ==========

enum class Rarity(val label: String, val color: Long, val xpMultiplier: Float) {
    N("N", 0xFFAAAAAA, 1.0f),
    R("R", 0xFF4169E1, 1.5f),
    SR("SR", 0xFFFFD700, 3.0f),
    SSR("SSR", 0xFFFF4444, 5.0f);
}

enum class Category(val label: String) {
    FOOD("食べ物"),
    NATURE("自然"),
    ANIMAL("動物"),
    PERSON("人物"),
    BUILDING("建物"),
    VEHICLE("乗り物"),
    ITEM("道具"),
    OTHER("その他");
}

data class ExamineEntry(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val category: Category,
    val rarity: Rarity,
    val timestamp: Long = System.currentTimeMillis(),
    val itemName: String = "",
)

data class Achievement(
    val id: String,
    val title: String,
    val description: String,
    val condition: (ProgressStore, CollectionStore) -> Boolean,
    var unlocked: Boolean = false,
    var unlockedAt: Long? = null,
)

data class Quest(
    val id: String,
    val title: String,
    val description: String,
    val targetCategory: Category?,
    val targetCount: Int,
    val rewardXp: Int,
    var progress: Int = 0,
    var completed: Boolean = false,
    var completedAt: Long? = null,
    var claimed: Boolean = false,
)

// ========== Collection Store ==========

class CollectionStore(context: Context) {

    private val prefs = context.getSharedPreferences("collection", Context.MODE_PRIVATE)
    private val imageDir = File(context.filesDir, "examine_images")

    fun addEntry(entry: ExamineEntry, thumbnail: Bitmap? = null) {
        val entries = getEntries().toMutableList()
        entries.add(0, entry)
        prefs.edit().putString("entries", entriesToJson(entries)).commit()
        if (thumbnail != null) saveEntryImage(entry.id, thumbnail)
    }

    fun getEntryImage(entryId: String): Bitmap? {
        val file = File(imageDir, "$entryId.jpg")
        return if (file.exists()) BitmapFactory.decodeFile(file.absolutePath) else null
    }

    private fun saveEntryImage(entryId: String, bitmap: Bitmap) {
        if (!imageDir.exists()) imageDir.mkdirs()
        val file = File(imageDir, "$entryId.jpg")
        FileOutputStream(file).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        }
    }

    fun getEntries(): List<ExamineEntry> {
        val json = prefs.getString("entries", null) ?: return emptyList()
        return jsonToEntries(json)
    }

    fun getCategoryCounts(): Map<Category, Int> {
        return getEntries().groupingBy { it.category }.eachCount()
    }

    fun getTotalCount(): Int = getEntries().size

    fun getUniqueCount(): Int {
        return getEntries().map { it.text }.distinct().count()
    }

    fun getEntriesByCategory(category: Category): List<ExamineEntry> {
        return getEntries().filter { it.category == category }
    }

    fun getRecentEntries(limit: Int = 50): List<ExamineEntry> {
        return getEntries().take(limit)
    }

    private fun entriesToJson(entries: List<ExamineEntry>): String {
        val arr = JSONArray()
        for (e in entries) {
            val obj = JSONObject()
            obj.put("id", e.id)
            obj.put("text", e.text)
            obj.put("category", e.category.name)
            obj.put("rarity", e.rarity.name)
            obj.put("timestamp", e.timestamp)
            obj.put("itemName", e.itemName)
            arr.put(obj)
        }
        return arr.toString()
    }

    private fun jsonToEntries(json: String): List<ExamineEntry> {
        val arr = JSONArray(json)
        return (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            ExamineEntry(
                id = obj.getString("id"),
                text = obj.getString("text"),
                category = try { Category.valueOf(obj.getString("category")) } catch (_: Exception) { Category.OTHER },
                rarity = try { Rarity.valueOf(obj.getString("rarity")) } catch (_: Exception) { Rarity.N },
                timestamp = obj.getLong("timestamp"),
                itemName = obj.optString("itemName", ""),
            )
        }
    }
}

// ========== Rarity Roller ==========

object RarityRoller {
    fun roll(): Rarity {
        val r = Math.random()
        return when {
            r < 0.03 -> Rarity.SSR
            r < 0.15 -> Rarity.SR
            r < 0.40 -> Rarity.R
            else -> Rarity.N
        }
    }
}

// ========== Combo Manager ==========

class ComboManager {
    var lastExamineTime: Long = 0
    var currentCombo: Int = 0

    fun recordExamine(): Int {
        val now = System.currentTimeMillis()
        if (lastExamineTime > 0 && now - lastExamineTime < 30_000) {
            currentCombo++
        } else {
            currentCombo = 1
        }
        lastExamineTime = now
        return currentCombo
    }

    fun getComboMultiplier(): Float {
        return when {
            currentCombo >= 10 -> 3.0f
            currentCombo >= 5 -> 2.0f
            currentCombo >= 3 -> 1.5f
            else -> 1.0f
        }
    }

    fun reset() {
        currentCombo = 0
        lastExamineTime = 0
    }
}

// ========== Achievements ==========

object AchievementDefinitions {

    val all: List<Achievement> = listOf(
        Achievement("first_exam", "鑑定のはじまり", "初めて鑑定する", condition = { _, col -> col.getTotalCount() >= 1 }),
        Achievement("exam_10", "鑑定入門者", "10回鑑定する", condition = { _, col -> col.getTotalCount() >= 10 }),
        Achievement("exam_50", "鑑定熟練者", "50回鑑定する", condition = { _, col -> col.getTotalCount() >= 50 }),
        Achievement("exam_100", "鑑定百人斬り", "100回鑑定する", condition = { _, col -> col.getTotalCount() >= 100 }),
        Achievement("exam_500", "鑑定の鬼", "500回鑑定する", condition = { _, col -> col.getTotalCount() >= 500 }),
        Achievement("rare_sr", "珍品発見！", "初めてSRを入手する", condition = { _, col -> col.getEntries().any { it.rarity == Rarity.SR } }),
        Achievement("rare_ssr", "至高の発見！！", "SSRを入手する", condition = { _, col -> col.getEntries().any { it.rarity == Rarity.SSR } }),
        Achievement("rare_ssr_3", "三冠王", "SSRを3つ入手する", condition = { _, col -> col.getEntries().count { it.rarity == Rarity.SSR } >= 3 }),
        Achievement("food_5", "美食家", "食べ物を5回鑑定する", condition = { _, col -> col.getEntriesByCategory(Category.FOOD).size >= 5 }),
        Achievement("nature_5", "自然探索者", "自然を5回鑑定する", condition = { _, col -> col.getEntriesByCategory(Category.NATURE).size >= 5 }),
        Achievement("animal_5", "動物学者", "動物を5回鑑定する", condition = { _, col -> col.getEntriesByCategory(Category.ANIMAL).size >= 5 }),
        Achievement("combo_3", "三連鑑定", "3コンボを達成する", condition = { _, _ -> false }),
        Achievement("combo_5", "五連鑑定", "5コンボを達成する", condition = { _, _ -> false }),
        Achievement("combo_10", "十連鑑定", "10コンボを達成する", condition = { _, _ -> false }),
        Achievement("all_cat", "全カテゴリ制覇", "全カテゴリを鑑定する", condition = { _, col -> Category.entries.all { cat -> col.getEntriesByCategory(cat).isNotEmpty() } }),
    )

    fun checkComboAchievement(comboCount: Int): List<Achievement> {
        val result = mutableListOf<Achievement>()
        if (comboCount >= 3) result.add(all.first { it.id == "combo_3" })
        if (comboCount >= 5) result.add(all.first { it.id == "combo_5" })
        if (comboCount >= 10) result.add(all.first { it.id == "combo_10" })
        return result
    }
}

// ========== Quest Definitions ==========

object QuestDefinitions {

    fun generateQuests(): List<Quest> = listOf(
        Quest("q_food_3", "料理人への道", "食べ物を3つ鑑定せよ", Category.FOOD, 3, 100),
        Quest("q_food_10", "美食の探求者", "食べ物を10つ鑑定せよ", Category.FOOD, 10, 500),
        Quest("q_nature_5", "自然を歩こう", "自然を5つ鑑定せよ", Category.NATURE, 5, 150),
        Quest("q_animal_3", "動物ファン", "動物を3つ鑑定せよ", Category.ANIMAL, 3, 100),
        Quest("q_person_3", "人物観察", "人物を3つ鑑定せよ", Category.PERSON, 3, 100),
        Quest("q_building_3", "建築巡り", "建物を3つ鑑定せよ", Category.BUILDING, 3, 100),
        Quest("q_rare_sr", "珍品ハンター", "SRを1つ入手せよ", null, 1, 300),
        Quest("q_rare_ssr", "至宝の発見", "SSRを1つ入手せよ", null, 1, 1000),
        Quest("q_exam_20", "鑑定の旅", "合計20回鑑定せよ", null, 20, 200),
        Quest("q_combo_5", "連続鑑定師", "5コンボを達成せよ", null, 1, 300),
    )
}

// ========== Category Inference ==========

object CategoryInferencer {

    private val foodKeywords = listOf("食べ物", "料理", "食", "味", "飲み", "果物", "野菜", "肉", "魚", "甘", "辛", "菓子", "パン", "ご飯", "ラーメン", "カフェ", "弁当", "スープ")
    private val natureKeywords = listOf("花", "木", "草", "植物", "山", "川", "海", "空", "雲", "雨", "石", "岩", "森", "公園", "自然", "湖", "星空", "夕焼け")
    private val animalKeywords = listOf("猫", "犬", "鳥", "動物", "ペット", "昆虫", "蝶", "うさぎ", "亀", "蛇", "馬", "牛", "豚", "ハムスター")
    private val personKeywords = listOf("人", "男性", "女性", "子供", "友達", "家族", "人間", "彼", "彼女", "姿", "人影", "selfie")
    private val buildingKeywords = listOf("建物", "家", "ビル", "店", "学校", "神社", "お寺", "教会", "城", "塔", "橋", "門", "駅")

    fun infer(text: String): Category {
        val counts = mutableMapOf(
            Category.FOOD to 0, Category.NATURE to 0, Category.ANIMAL to 0,
            Category.PERSON to 0, Category.BUILDING to 0,
        )
        for (keyword in foodKeywords) { if (text.contains(keyword)) counts[Category.FOOD] = counts.getOrDefault(Category.FOOD, 0) + 1 }
        for (keyword in natureKeywords) { if (text.contains(keyword)) counts[Category.NATURE] = counts.getOrDefault(Category.NATURE, 0) + 1 }
        for (keyword in animalKeywords) { if (text.contains(keyword)) counts[Category.ANIMAL] = counts.getOrDefault(Category.ANIMAL, 0) + 1 }
        for (keyword in personKeywords) { if (text.contains(keyword)) counts[Category.PERSON] = counts.getOrDefault(Category.PERSON, 0) + 1 }
        for (keyword in buildingKeywords) { if (text.contains(keyword)) counts[Category.BUILDING] = counts.getOrDefault(Category.BUILDING, 0) + 1 }

        val max = counts.maxByOrNull { it.value }
        return if (max != null && max.value > 0) max.key else Category.OTHER
    }
}

// ========== Date Formatting ==========

object DateFormatter {
    private val sdf = SimpleDateFormat("MM/dd HH:mm", Locale.JAPAN)

    fun format(timestamp: Long): String = sdf.format(Date(timestamp))
}
