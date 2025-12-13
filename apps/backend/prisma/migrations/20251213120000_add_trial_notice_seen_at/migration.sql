-- Add trialStartedNoticeSeenAt to Subscription for one-time trial started notice
ALTER TABLE "Subscription" ADD COLUMN "trialStartedNoticeSeenAt" TIMESTAMP(3);


