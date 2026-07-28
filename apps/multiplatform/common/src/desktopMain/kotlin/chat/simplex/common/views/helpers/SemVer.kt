package chat.simplex.common.views.helpers

import chat.simplex.common.BuildConfigCommon
import chat.simplex.common.platform.appPlatform

data class SemVer(
  val major: Int,
  val minor: Int,
  val patch: Int,
  val preRelease: String? = null,
  val buildNumber: Int? = null,
): Comparable<SemVer?> {

  val isNotStable: Boolean = preRelease != null

  override fun compareTo(other: SemVer?): Int {
    if (other == null) return 1
    return when {
      major != other.major -> major.compareTo(other.major)
      minor != other.minor -> minor.compareTo(other.minor)
      patch != other.patch -> patch.compareTo(other.patch)
      preRelease != null && other.preRelease != null -> {
        val pr = preRelease.compareTo(other.preRelease, ignoreCase = true)
        when {
          pr != 0 -> pr
          buildNumber != null && other.buildNumber != null -> buildNumber.compareTo(other.buildNumber)
          buildNumber != null -> -1
          other.buildNumber != null -> 1
          else -> 0
        }
      }
      preRelease != null -> -1
      other.preRelease != null -> 1
      else -> 0
    }
  }

  companion object {
    private val regex = Regex("^(\\d+)\\.(\\d+)\\.(\\d+)(?:-([A-Za-z]+)\\.(\\d+))?\$")
    fun from(tagName: String): SemVer? {
      val trimmed = tagName.trimStart { it == 'v' }
      val redacted = when {
        trimmed.contains('-') && trimmed.substringBefore('-').count { it == '.' } == 1 -> "${trimmed.substringBefore('-')}.0-${trimmed.substringAfter('-')}"
        trimmed.substringBefore('-').count { it == '.' } == 1 -> "${trimmed}.0"
        else -> trimmed
      }
      val group = regex.matchEntire(redacted)?.groups
      return if (group != null) {
        SemVer(
          major = group[1]?.value?.toIntOrNull() ?: return null,
          minor = group[2]?.value?.toIntOrNull() ?: return null,
          patch = group[3]?.value?.toIntOrNull() ?: return null,
          preRelease = group[4]?.value,
          buildNumber = group[5]?.value?.toIntOrNull(),
        )
      } else {
        null
      }
    }

    fun fromCurrentVersionName(): SemVer? {
      val currentVersionName = if (appPlatform.isAndroid) BuildConfigCommon.ANDROID_VERSION_NAME else BuildConfigCommon.DESKTOP_VERSION_NAME
      return from(currentVersionName)
    }
  }
}
