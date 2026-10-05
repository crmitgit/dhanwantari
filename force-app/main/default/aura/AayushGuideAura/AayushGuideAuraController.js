({
    doInit : function(component, event, helper) {
        var action = component.get("c.validateEncounter");
        action.setParams({ clinicalEncounterId: component.get("v.recordId") });

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
            }
        });
        $A.enqueueAction(action);
    },

    handleCancel : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})