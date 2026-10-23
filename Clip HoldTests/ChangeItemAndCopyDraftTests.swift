import Testing
@testable import Clip_Hold

struct ChangeItemAndCopyDraftTests {
    @Test(arguments: ["元の文章", "", "改行\nと空白 "])
    func unchangedContentDoesNotRequireConfirmation(content: String) {
        let draft = ChangeItemAndCopyDraft(content: content)
        #expect(!draft.hasChanges)
    }

    @Test(arguments: ["置換後の文章", "", "元の文章 ", "元の文章\n"])
    func editedContentRequiresConfirmation(content: String) {
        var draft = ChangeItemAndCopyDraft(content: "元の文章")
        draft.content = content
        #expect(draft.hasChanges)
        #expect(draft.originalContent == "元の文章")
    }

    @Test
    func revertingEditsClearsChanges() {
        var draft = ChangeItemAndCopyDraft(content: "元の文章")
        draft.content = "編集後の文章"
        draft.content = "元の文章"
        #expect(!draft.hasChanges)
    }

    @Test
    func enteringNewContentRequiresConfirmation() {
        var draft = ChangeItemAndCopyDraft(content: "")
        draft.content = "新しい文章"
        #expect(draft.hasChanges)
    }
}
