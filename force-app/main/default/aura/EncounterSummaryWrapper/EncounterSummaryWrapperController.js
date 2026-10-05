({

    handleClose: function (component, event, helper) {
        component.set("v.isOpen", false);
        var dismissActionPanel = $A.get("e.force:closeQuickAction");
        dismissActionPanel.fire();
    }
})