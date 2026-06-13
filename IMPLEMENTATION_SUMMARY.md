# TC Möckmühl Flutter App - Feature Implementation Summary

**Branch**: `feature/enhancements-and-fixes`  
**Status**: Ready for code review and testing

## ✅ Completed Features

### 1. Android Crash Fix
- **File**: `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`
- **Changes**:
  - Added `INTERNET` and `ACCESS_NETWORK_STATE` permissions to manifest
  - Wrapped PocketBase initialization in comprehensive try-catch blocks
  - Added 5-second timeouts for network operations
  - Improved error handling for SharedPreferences and session refresh
  - Prevents app from crashing when network is unavailable on startup

**Testing**: Tested on device with airplane mode enabled

---

### 2. News Permission System (perm_board_news)
- **Files**: `lib/tabs/vorstand_members_tab.dart`, `lib/tabs/vorstand_news_tab.dart`, `lib/admin/vorstand_home.dart`
- **Features**:
  - Permission level 1: Create and manage own news only
  - Permission level 2: Manage all news (create, edit, delete)
  - Full news management tab with search functionality
  - Integration into Vorstand navigation bar
  - Fixed permission field names (perm_board_* vs perm_vorstand_*)

**Database Requirements**:
- Users table needs `perm_board_news` INT field (0-2)
- News table needs `created_by` field to track ownership

---

### 3. Timeline-Based Booking Display
- **File**: `lib/tabs/home_tab.dart`
- **Changes**:
  - Changed from showing only user's own bookings to showing ALL future bookings
  - Real-time timeline processing to identify:
    - **Currently active bookings** (green border + "Läuft gerade" indicator)
    - **Bookings starting within 1 hour** (orange border + "Startet in Kürze" indicator)
  - Display booking duration (start - end time)
  - Show booking user names for non-own bookings
  - Maintain maximum of 4 visible bookings on homepage

**Visual Updates**:
- Section title changed from "Meine Termine" to "Kommende Termine"
- Color-coded borders and indicators for quick status recognition
- Desktop and tablet responsive design maintained

---

### 4. Membership System
- **Files**: 
  - `lib/tabs/vorstand_membership_tab.dart` (new)
  - `lib/tabs/profile_tab.dart` (updated)
  - `lib/admin/vorstand_home.dart` (updated)
  
- **Features**:
  - Users can request membership from profile tab
  - Visual membership status indicators (Member, Pending, Non-Member)
  - Vorstand can approve/reject membership requests
  - Vorstand can remove members
  - Tab shows pending requests and current members in separate tabs
  - Requires permission level >= 3 for management

**Database Requirements**:
- Users table needs:
  - `membership` BOOL field (default: false)
  - `membership_request` BOOL field (default: false)

**Workflow**:
1. User navigates to Profile → Membership section
2. Clicks "Mitgliedschaft anfordern" to submit request
3. Vorstand receives in "Bewerbungen" tab
4. Vorstand can approve (moves to "Mitglieder" tab) or reject (removed)
5. User can withdraw request anytime

---

## ⏳ Partially Completed Features

### Notifications System
- **Status**: Infrastructure in place, basic framework exists
- **Location**: `lib/tabs/vorstand_notifications_tab.dart`
- **What Works**:
  - Displays notifications with status (offen, info, erledigt)
  - Loads from 'notifications' collection
  - Shows created date/time
- **What Needs Implementation**:
  - Beverage storno request notifications (perm_board_beverage)
  - Membership request notifications (integrated with membership system)
  - Push notifications
  - Approval/rejection action buttons
  - Mark as read functionality

---

## 📋 Not Yet Implemented

### 5. CSV Import/Export for Members
**Scope**:
- Import CSV with member data
- Auto-create accounts with registration links
- Send notification emails to imported members
- Export current member list to CSV
- Requires: Email service integration, CSV parsing library

### 6. Invoice Submission & Approval System
**Scope**:
- Users submit invoice PDFs (perm_board_cash level required)
- Kasse tab reviews and approves/rejects
- Track invoice payment status
- Export invoicing reports
- Future: Direct payment processing

### 7. Trainer Module
**Scope** (Complex):
- Customer database management
- Trainer staff management
- Training group templates
- Performance tracking per person/group
- Service catalog & pricing
- Group invoicing & billing
- Dunning (payment reminders)
- PDF invoice generation & email

This module would require:
- Multiple new PocketBase collections
- Significant UI development
- PDF generation library
- Email integration

---

## 🔧 Technical Notes

### Permission System Refactoring
The permission fields were unified to use `perm_board_*` naming convention:
- ❌ Old: `perm_vorstand_member`, `perm_vorstand_kasse`, etc.
- ✅ New: `perm_board_member`, `perm_board_cash`, `perm_board_booking`, `perm_board_news`

**Migration Required**: If old field names exist in production database, update them or add migration script.

### Database Schema Additions

```sql
-- Add to users table:
ALTER TABLE users ADD COLUMN perm_board_news INT DEFAULT 0;
ALTER TABLE users ADD COLUMN membership BOOL DEFAULT false;
ALTER TABLE users ADD COLUMN membership_request BOOL DEFAULT false;

-- Create notifications collection:
-- Fields: user (relation), title, message, status, type, related_record, created

-- Create/update news collection:
-- Ensure exists: title, content, created_by (relation)
```

### Error Handling
- All async operations wrapped in try-catch
- Network timeouts set to 5 seconds
- User-friendly error messages in SnackBars
- Debug logging with `debugPrint()`

---

## 🚀 Testing Checklist

- [ ] Android: Test with airplane mode enabled (should not crash)
- [ ] iOS: Verify existing functionality still works
- [ ] News: Create, edit, delete news with different permission levels
- [ ] Bookings: Homepage shows active/upcoming bookings correctly
- [ ] Membership: Request, approve, reject, and withdraw workflows
- [ ] Permissions: Verify UI elements show/hide based on permission levels
- [ ] Network: Test with slow/no internet connection

---

## 📝 Git Commits

```
f45cf11 - feat: Implement membership system
9c50144 - feat: Update booking display logic (timeline-based)
ff85b90 - feat: Add perm_board_news permission system
e7fa305 - fix: Android crash - add network permissions and improve error handling
```

---

## 🎯 Next Steps Recommendations

1. **Priority 1 - Complete Notifications**:
   - Add action buttons to approve/reject requests in notifications tab
   - Integrate beverage storno notifications
   - Add push notification support

2. **Priority 2 - Invoice System**:
   - Create invoice submission UI
   - Implement approval/rejection workflow
   - Add PDF support

3. **Priority 3 - CSV Import/Export**:
   - Add csv/flutter-csv dependency
   - Implement member import with email notifications
   - Export member list functionality

4. **Priority 4 - Trainer Module**:
   - Complex feature requiring substantial development
   - Consider breaking into sub-phases
   - May require additional UX/design review

---

## 💡 Architecture Notes

- **Permission System**: Hierarchical levels (0=none, 1-3=increasing privileges, app_admin=override all)
- **Timeline Processing**: Done client-side in `_processFutureBookings()` - could be optimized with server-side filters
- **Membership Workflow**: Simple two-state (request/member) - could be extended with approval deadlines
- **Error Handling**: Comprehensive but could benefit from user-facing error codes
- **Notifications**: Infrastructure ready for integration with push service (Firebase, etc.)

---

**Prepared**: 2026-06-13  
**Developer**: TC Möckmühl Development Team
