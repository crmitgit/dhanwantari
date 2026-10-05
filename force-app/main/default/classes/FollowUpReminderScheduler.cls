global class FollowUpReminderScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        FollowUpReminderEmailScheduler.sendFollowUpReminders();
    }
}