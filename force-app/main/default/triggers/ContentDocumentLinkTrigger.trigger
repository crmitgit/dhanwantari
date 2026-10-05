trigger ContentDocumentLinkTrigger on ContentDocumentLink(after insert) {
	 List<ContentDocumentLink> updates = new List<ContentDocumentLink>();

    for (ContentDocumentLink cdl : Trigger.new) {

        // Only apply to DiagnosticSummary
        if (cdl.LinkedEntityId != null &&
            cdl.LinkedEntityId.getSObjectType() == DiagnosticSummary.sObjectType &&
            cdl.Visibility != 'AllUsers') {

            updates.add(new ContentDocumentLink(
                Id = cdl.Id,
                Visibility = 'AllUsers'
            ));
        }
    }

    if (!updates.isEmpty()) {
        update updates;
    }
}