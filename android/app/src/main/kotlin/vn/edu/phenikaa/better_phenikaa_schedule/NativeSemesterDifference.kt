package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import java.util.Locale

internal object NativeSemesterDifference {
    fun compare(previousJson: String?, nextJson: String): String {
        val next = JSONObject(nextJson)
        if (previousJson == null) {
            return result(true, JSONArray(), JSONArray(), counts(0, 0, 0), counts(0, 0, 0))
                .toString()
        }
        val previous = JSONObject(previousJson)
        val oldSubjects = subjects(previous.getJSONArray("subjects"))
        val newSubjects = subjects(next.getJSONArray("subjects"))
        val addedNames = JSONArray()
        val removedNames = JSONArray()
        val added = newSubjects.filterKeys { it !in oldSubjects }
        val removed = oldSubjects.filterKeys { it !in newSubjects }
        added.values.forEach { addedNames.put(it.getString("name")) }
        removed.values.forEach { removedNames.put(it.getString("name")) }
        val shared = oldSubjects.keys.intersect(newSubjects.keys)
        val study = compareSchedules(oldSubjects, newSubjects, shared, added, removed, "studySchedules")
        val exams = compareSchedules(oldSubjects, newSubjects, shared, added, removed, "examSchedules")
        return result(false, addedNames, removedNames, study, exams).toString()
    }

    private fun subjects(items: JSONArray): Map<String, JSONObject> = buildMap {
        for (index in 0 until items.length()) {
            val item = items.getJSONObject(index)
            val id = item.getString("subjectId")
            require(id !in this) { "Trùng ID môn trong học kỳ." }
            put(id, item)
        }
    }

    private fun compareSchedules(
        old: Map<String, JSONObject>,
        next: Map<String, JSONObject>,
        shared: Set<String>,
        added: Map<String, JSONObject>,
        removed: Map<String, JSONObject>,
        field: String,
    ): JSONObject {
        val remaining = shared.flatMap { rows(next.getValue(it), field) }.toMutableList()
        val unmatched = mutableListOf<JSONObject>()
        shared.flatMap { rows(old.getValue(it), field) }.forEach { row ->
            val index = remaining.indexOfFirst { sameContent(row, it) }
            if (index < 0) unmatched.add(row) else remaining.removeAt(index)
        }
        var modified = 0
        val changed = mutableListOf<JSONObject>()
        for (row in unmatched.toList()) {
            val sameDay = remaining.indexOfFirst {
                norm(it.getString("subjectName")) == norm(row.getString("subjectName")) &&
                    it.getString("startAt").take(10) == row.getString("startAt").take(10)
            }
            val match = if (sameDay >= 0) sameDay else if (
                remaining.size == 1 && unmatched.size == 1 &&
                norm(remaining.first().getString("subjectName")) == norm(row.getString("subjectName"))
            ) 0 else -1
            if (match >= 0) {
                modified++
                changed.add(change("modified", row, remaining[match]))
                remaining.removeAt(match)
                unmatched.remove(row)
            }
        }
        val addedCount = remaining.size + added.values.sumOf { it.getJSONArray(field).length() }
        val removedCount = unmatched.size + removed.values.sumOf { it.getJSONArray(field).length() }
        val details = JSONArray()
        changed.forEach { details.put(it) }
        remaining.forEach { details.put(change("added", null, it)) }
        unmatched.forEach { details.put(change("removed", it, null)) }
        added.values.flatMap { rows(it, field) }.forEach { details.put(change("added", null, it)) }
        removed.values.flatMap { rows(it, field) }.forEach { details.put(change("removed", it, null)) }
        return counts(addedCount, removedCount, modified).put("details", details)
    }

    private fun change(kind: String, before: JSONObject?, after: JSONObject?): JSONObject =
        JSONObject().put("kind", kind).put("before", before ?: JSONObject.NULL)
            .put("after", after ?: JSONObject.NULL)

    private fun rows(subject: JSONObject, field: String): List<JSONObject> {
        val array = subject.getJSONArray(field)
        return (0 until array.length()).map(array::getJSONObject)
    }

    private fun sameContent(a: JSONObject, b: JSONObject): Boolean =
        listOf("subjectName", "className", "room", "examForm").all {
            norm(a.optString(it)) == norm(b.optString(it))
        } && listOf("startAt", "endAt", "periodStart", "periodEnd").all {
            a.opt(it).toString() == b.opt(it).toString()
        }

    private fun norm(value: String): String = Normalizer.normalize(
        value.trim().replace(Regex("\\s+"), " ").lowercase(Locale.ROOT),
        Normalizer.Form.NFD,
    )

    private fun counts(added: Int, removed: Int, modified: Int): JSONObject = JSONObject()
        .put("added", added).put("removed", removed).put("modified", modified)

    private fun result(
        initial: Boolean,
        added: JSONArray,
        removed: JSONArray,
        study: JSONObject,
        exams: JSONObject,
    ): JSONObject = JSONObject()
        .put("initial", initial)
        .put("addedSubjects", added)
        .put("removedSubjects", removed)
        .put("study", study)
        .put("exams", exams)
}
