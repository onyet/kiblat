# Implementation Plan: Fix Ad Content Rating for Family Policy Compliance

This plan addresses the "Family Policy: Ad Content" violation reported by Google Play. We will restrict the maximum rating of ads shown in the app to "G" (General), which is consistent with the app's "All User 3+" content rating.

## User Review Required

> [!IMPORTANT]
> This change strictly limits the types of ads shown to the "G" rating. While this ensures compliance with Google Play's Family Policy, it may slightly affect ad fill rates as more mature ads will be filtered out. However, this is mandatory for maintaining the app's presence on the Play Store under the Family category.

## Proposed Changes

### [AdMob] Global Request Configuration

We will update the AdMob initialization logic to apply a global `RequestConfiguration` that enforces the content rating and child-directed tagging.

#### [MODIFY] [ad_service.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/services/ad_service.dart)
- Update `AdService.initialize()` to call `MobileAds.instance.updateRequestConfiguration()`.
- Set `maxAdContentRating` to `MaxAdContentRating.g`.
- Set `tagForChildDirectedTreatment` to `TagForChildDirectedTreatment.yes` (since the app's target audience includes users under 13).
- Set `tagForUnderAgeOfConsent` to `TagForUnderAgeOfConsent.yes` to comply with European regulations for younger users.

## Verification Plan

### Automated Tests
- Check for successful compilation of the `AdService` with the new configuration.

### Manual Verification
- Observe the ads shown in debug mode (test ads) to ensure they load correctly with the new configuration.
- Note: Actual ad content filtering is enforced on the server-side by Google once the request configuration is sent, so local "visual" verification of content rating is limited to checking if ads still load.
