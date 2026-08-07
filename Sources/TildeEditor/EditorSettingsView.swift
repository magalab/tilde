import SwiftUI
import TildeCore

public struct EditorSettingsView: View {
    public static let preferredContentSize = CGSize(width: 480, height: 430)

    @Bindable private var settings: EditorSettings

    public init(settings: EditorSettings) {
        self.settings = settings
    }

    public var body: some View {
        TabView {
            editorTab
                .tabItem {
                    Label(L10n.string("Editor"), systemImage: "textformat")
                }

            filesTab
                .tabItem {
                    Label(L10n.string("Files"), systemImage: "doc.text")
                }

            markdownTab
                .tabItem {
                    Label(L10n.string("Markdown"), systemImage: "text.document")
                }

            appearanceTab
                .tabItem {
                    Label(L10n.string("Appearance"), systemImage: "paintbrush")
                }
        }
        .padding(12)
        .frame(
            width: Self.preferredContentSize.width,
            height: Self.preferredContentSize.height
        )
    }

    private var editorTab: some View {
        Form {
            Section(L10n.string("Text Editing")) {
                Picker(L10n.string("Font"), selection: $settings.fontChoice) {
                    ForEach(settings.availableFonts) { font in
                        Text(font.title).tag(font)
                    }
                }
                .pickerStyle(.menu)

                Toggle(L10n.string("Enable font ligatures"), isOn: $settings.fontLigatures)

                LabeledContent(L10n.string("Font Size")) {
                    HStack(spacing: 6) {
                        Text("\(Int(settings.fontSize)) pt")
                            .monospacedDigit()
                        Stepper(
                            L10n.string("Font Size"),
                            value: Binding(
                                get: { settings.fontSize },
                                set: { settings.setFontSize($0) }
                            ),
                            in: 8...72,
                            step: 1
                        )
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityLabel(L10n.string("Font Size"))
                    }
                }

                Toggle(L10n.string("Wrap lines to editor width"), isOn: $settings.wordWrap)
                Toggle(L10n.string("Show line numbers"), isOn: $settings.showLineNumbers)

                LabeledContent(L10n.string("Tab Width")) {
                    HStack(spacing: 6) {
                        Text("\(settings.tabWidth)")
                            .monospacedDigit()
                        Stepper(
                            L10n.string("Tab Width"),
                            value: Binding(
                                get: { settings.tabWidth },
                                set: { settings.setTabWidth($0) }
                            ),
                            in: 1...16
                        )
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityLabel(L10n.string("Tab Width"))
                    }
                }

                Picker(L10n.string("Indent Using"), selection: $settings.indentStyle) {
                    Text(L10n.string("Spaces")).tag(IndentStyle.spaces)
                    Text(L10n.string("Tabs")).tag(IndentStyle.tabs)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    private var filesTab: some View {
        Form {
            Section(L10n.string("New Documents")) {
                Picker(L10n.string("Default Encoding"), selection: $settings.defaultEncoding) {
                    ForEach(DefaultEncodingChoice.allCases, id: \.self) { encoding in
                        Text(encoding.title).tag(encoding)
                    }
                }
                Picker(L10n.string("Default Line Ending"), selection: $settings.defaultLineEnding) {
                    ForEach(LineEnding.allCases, id: \.self) { lineEnding in
                        Text(lineEnding.localizedName).tag(lineEnding)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var markdownTab: some View {
        Form {
            Section(L10n.string("Preview")) {
                Picker(L10n.string("Preview Theme"), selection: $settings.previewTheme) {
                    ForEach(PreviewTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section(L10n.string("Application")) {
                Picker(L10n.string("Application Theme"), selection: $settings.applicationTheme) {
                    ForEach(ApplicationTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Picker(L10n.string("Open New Windows"), selection: $settings.windowOpeningMode) {
                    ForEach(WindowOpeningMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
