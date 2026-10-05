/**
 * Runs the Referral_Validation prompt for one referral and stores the verdict on it.
 * Enqueued by ReferralValidationRequestTrigger, so it runs as the internal user configured in
 * ReferralValidationRequestConfig rather than the portal guest user.
 */
public class ReferralValidationJob implements Queueable, Database.AllowsCallouts {

    private final Id referralId;

    public ReferralValidationJob(Id referralId) {
        this.referralId = referralId;
    }

    public void execute(QueueableContext context) {
        ReferralValidationService.runValidation(referralId);
    }
}