# MGTS Orders & Expenses Hub - End-to-End Test Plan

**Date:** 23 June 2026  
**Build:** cc31c65 (Finance enhancements)  
**Tester:** Janet Allbon (Finance)

---

## Test Summary

This document outlines end-to-end testing for 5 new features implemented to improve the finance workflow.

---

## Feature 1: Dashboard - Finance Visibility by Manager ✅ CODE VERIFIED

**What Changed:**
- Finance dashboard now shows pending items **grouped by manager** instead of a simple count
- Shows which managers have items awaiting their approval
- Helps Finance understand approval bottlenecks

**How to Test:**
1. Log in as **Finance user** (Finance role)
2. Go to **Dashboard** tab
3. Look for section: **"Pending Manager Approval — By Manager"**
4. **Expected Result:** 
   - Should see grouped table with manager names and count of pending items
   - Each manager's pending items should be listed with Ref, Type, From, Amount
   - "Review" button should open each item

**Code Location:** `index.html` lines 1366-1404  
**Status:** ✅ IMPLEMENTED

---

## Feature 2: Expense Claim - Print & Export ✅ CODE VERIFIED

**What Changed:**
- When viewing an **Approved/Authorised/Processed** expense claim
- Two new buttons appear: **🖨 Print** and **📊 Export XLSX**
- Print generates a professional PDF-ready receipt for Opera system
- Export creates Excel file with all claim details

**How to Test:**

### Test 2A: Print Button
1. Navigate to **Expenses** tab
2. Find an expense claim with status: **Approved**, **Authorised**, or **Processed**
3. Click **View** button
4. Scroll down to footer buttons
5. Click **🖨 Print** button
6. **Expected Result:**
   - New window opens with formatted claim document
   - Shows: Ref, Employee, Department, Month, Status
   - Displays all expense lines with date, description, cost, VAT, ex VAT
   - Shows totals: Subtotal, VAT, Total Amount Due
   - Shows approval signatures (approved by / date)
   - Print dialog appears automatically

### Test 2B: Export XLSX Button
1. Same claim as above
2. Click **📊 Export XLSX** button
3. **Expected Result:**
   - Excel file downloads: `Expense_Claim_[RefNumber].xlsx`
   - File contains:
     - Header with claim ref, employee, department, month, status
     - Expense lines table with columns: Date, Description, Cost, VAT Applied, Cost ex VAT, VAT Amount, NL Code
     - Totals section: Subtotal, VAT, Total
     - Approval info: Who approved and when

**Code Location:** 
- Print function: `index.html` lines 3217-3323
- Export function: `index.html` lines 3324-3374
- Buttons added: `index.html` lines 1809-1810

**Status:** ✅ IMPLEMENTED

---

## Feature 3: Mileage Claims - Journey Log Totals ✅ CODE VERIFIED

**What Changed:**
- Mileage claim form now displays **total journey miles** in real-time
- Shows below the journey log table
- Updates automatically as journeys are added/edited

**How to Test:**
1. Navigate to **Mileage** tab
2. Click **+ New Claim** button
3. Fill in basic details (Employee, Month, Vehicle Type)
4. **Add Journeys:**
   - Click **+ Add Journey** button
   - Enter journey miles: `25` miles
   - Click **+ Add Journey** again
   - Enter journey miles: `15` miles
5. **Expected Result:**
   - Below the journey table you should see:
     - **"Journey Log Total: 40.0 miles"**
   - Total updates automatically when journeys are added/removed

**Code Location:** 
- Display box: `index.html` lines 973-982
- Calculation: `index.html` lines 2134-2147

**Status:** ✅ IMPLEMENTED

---

## Feature 4: Mileage Claims - Deduct Commute per Journey ✅ CODE VERIFIED

**What Changed:**
- New **"Deduct Commute"** checkbox added to each journey row
- Allows marking individual journeys where daily commute should be deducted
- Shows running total of commute miles being deducted
- Data persists when saving claims

**How to Test:**
1. In the Mileage claim from Feature 3 (or create new one)
2. In the Journey Log table, you should see 4 columns now:
   - Date
   - From / To Postcode & Description
   - Miles
   - **Deduct Commute** (NEW - checkbox column)
3. **Add journeys with commute deductions:**
   - Journey 1: 25 miles, **CHECK** "Deduct Commute"
   - Journey 2: 15 miles, uncheck "Deduct Commute"
4. **Enter daily commute distance:**
   - Scroll down to: "Daily Commute Distance (miles)" field
   - Enter: `5` miles
5. **Expected Result:**
   - Below journey table you should see:
     - **"Journey Log Total: 40.0 miles"**
     - **"Commute Miles to Deduct: 5.0 miles"** (only from journey 1)
   - When you save and reload, checkboxes should be remembered

**Code Location:**
- Journey table header: `index.html` lines 965-972
- Checkbox in row: `index.html` line 2092
- Calculation: `index.html` lines 2140-2150
- Save data: `index.html` lines 2186

**Status:** ✅ IMPLEMENTED

---

## Feature 5: Admin Settings - Mileage Rates Management ✅ CODE VERIFIED

**What Changed:**
- New **"Rates & Settings"** tab added to Admin panel
- Finance can view and update standard mileage rates
- Rates update automatically when saved
- Shows last updated timestamp

**How to Test:**
1. Log in as **Finance user**
2. Go to **Admin** tab
3. You should see new inner tab: **"Rates & Settings"**
4. Click it
5. **Expected Content:**
   - Section title: "Mileage Rates & Settings"
   - Input fields for:
     - **Car (up to 10,000 miles/year):** pence per mile (default: 45)
     - **Car (over 10,000 miles/year):** pence per mile (default: 25)
     - **Motorcycle:** pence per mile (default: 24)
     - **Bicycle:** pence per mile (default: 20)
     - **Overnight Stay Allowance:** £ per night (default: 35)
   - "Last Updated:" field (shows never/date/time)
   - "Updated By:" field (shows user name)
   - **"Save Settings"** button

6. **Test Saving:**
   - Change Car (up to 10k) from 45 to 50
   - Click **Save Settings**
   - **Expected Result:**
     - Toast message: "Mileage rates updated successfully."
     - "Last Updated:" shows current date/time
     - "Updated By:" shows your name
     - When you close and reopen, values should be saved

**Code Location:**
- HTML Panel: `index.html` lines 490-524
- Load function: `index.html` lines 2887-2915
- Save function: `index.html` lines 2917-2941
- Tab registration: `index.html` lines 2387, 2390

**Status:** ✅ IMPLEMENTED

---

## BONUS: Vehicle Type Dropdown Update ✅ CODE VERIFIED

**What Changed:**
- Updated HMRC mileage rates in vehicle type dropdown
- Now uses current 2024/2025 standard rates

**How to Test:**
1. Open a **Mileage Claim** (new or existing)
2. Click **Vehicle Type** dropdown
3. **Expected Options:**
   - ✅ Own Car (up to 10,000 miles) — £0.45/mile (HMRC)
   - ✅ Own Car (over 10,000 miles) — £0.25/mile (HMRC)
   - ✅ Motorcycle — £0.24/mile (HMRC)
   - ✅ Bicycle — £0.20/mile (HMRC)

**Code Location:** `index.html` lines 961-964  
**Status:** ✅ IMPLEMENTED

---

## Test Checklist

### Finance User (Janet Allbon)
- [ ] Dashboard shows pending items by manager
- [ ] Can print approved expense claims
- [ ] Can export approved expense claims to Excel
- [ ] Can access Admin > Rates & Settings
- [ ] Can update mileage rates
- [ ] Rates are saved and persist

### Manager User (Ruth Smith / Adam Murray)
- [ ] Can see journey log totals in mileage claims
- [ ] Can check "Deduct Commute" on journeys
- [ ] Commute deduction totals display correctly
- [ ] Deduct commute settings persist when saving

### All Users
- [ ] No console errors
- [ ] All new buttons visible on appropriate screens
- [ ] Forms submit successfully
- [ ] Data persists after save/reload

---

## Known Issues / Caveats

**Issues #2 & #4 (Not Implemented - Require DB Investigation):**
- Duplicate expense claims - needs database constraint check
- "Approved by Adam" but still Pending - needs data audit

**These require direct database access and are flagged as separate tasks.**

---

## Build Information

- **Commit:** cc31c65
- **Branch:** main
- **Files Changed:** index.html (+348 lines, -17 lines)
- **New Functions:**
  - `printExpenseClaim(id)`
  - `exportExpenseClaimXLSX(id)`
  - `loadRatesSettings()`
  - `saveRatesSettings()`

---

## Sign-Off

- [ ] Feature 1 (Dashboard) - Verified by: __________ Date: __________
- [ ] Feature 2 (Expense Export) - Verified by: __________ Date: __________
- [ ] Feature 3 (Journey Totals) - Verified by: __________ Date: __________
- [ ] Feature 4 (Deduct Commute) - Verified by: __________ Date: __________
- [ ] Feature 5 (Rates Management) - Verified by: __________ Date: __________

**All Features Passed:** __________ Date: __________
