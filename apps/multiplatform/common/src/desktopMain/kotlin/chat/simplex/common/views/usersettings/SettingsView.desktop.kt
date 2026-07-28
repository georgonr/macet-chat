package chat.simplex.common.views.usersettings

import SectionView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import chat.simplex.common.model.ChatModel
import chat.simplex.common.ui.theme.DEFAULT_PADDING_HALF
import chat.simplex.common.views.helpers.*
import chat.simplex.res.MR
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource

@Composable
actual fun SettingsSectionApp(
  showSettingsModal: (@Composable (ChatModel) -> Unit) -> (() -> Unit),
  showVersion: () -> Unit,
  withAuth: (title: String, desc: String, block: () -> Unit) -> Unit
) {
  SectionView(stringResource(MR.strings.settings_section_title_app)) {
    SettingsActionItem(painterResource(MR.images.ic_code), stringResource(MR.strings.settings_developer_tools), showSettingsModal { DeveloperView(withAuth) })
    // No in-app update check - upstream's checked the SimpleX GitHub releases and offered to
    // install them over this app. Macet desktop builds are distributed separately.
    AppVersionItem(showVersion)
  }
}
