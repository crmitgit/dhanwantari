({
    doInit : function(component, event, helper) {
        var action = component.get("c.validateEncounter");
        action.setParams({ clinicalEncounterId: component.get("v.recordId") });

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                if (result !== "VALID") {
                    // Show toast with missing data
                    var toast = $A.get("e.force:showToast");
                    toast.setParams({
                        "title": "Cannot Open Medication Guide",
                        "message": result,
                        "type": "error"
                    });
                    toast.fire();
                    
                    // Close the modal
                    $A.get("e.force:closeQuickAction").fire();
                }
            }
        });
        $A.enqueueAction(action);
    },

    handleCancel : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})