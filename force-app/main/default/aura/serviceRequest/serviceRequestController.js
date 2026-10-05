({
    handleCancel: function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire(); // This closes the modal
    }
})