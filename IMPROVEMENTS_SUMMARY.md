# Qurbani & Aqiqah Planner - Improvements Summary

**Date:** 2026-08-17  
**Module:** Qurbani Planner Screen (`lib/screens/qurbani_planner_screen.dart`)

---

## Overview
This document outlines all the improvements made to the Eligibility Module, Calculator/Shares Module, and Aqiqah Planner based on user feedback. These enhancements provide better clarity, more flexibility, and improved user control over cost calculations.

---

## 1. **ELIGIBILITY MODULE - Save & Manage Responses**

### Features Added:
- ✅ **Eligibility History Tracking**: All eligibility checks are now saved automatically
  - Timestamp of each check
  - Net assets calculated
  - Eligibility status (WAJIB/Optional)
  - Suggested shares based on net assets
  
- ✅ **History Display**: Shows up to 10 most recent eligibility checks
  - Delete individual records with one tap
  - View previous calculations at a glance
  - Easy to track changes over time

- ✅ **Smart Share Suggestions**: Based on your net assets, the app now calculates and suggests:
  - How many shares you should ideally take (1-7 shares)
  - Clear explanation tied to Nisab thresholds
  - Direct link to Calculator tab to apply suggestions

### How to Use:
1. Go to **Eligibility Tab**
2. Enter your savings, gold/silver value, cash, and debts
3. Tap **"Evaluate Eligibility"**
4. See your eligibility result + **suggested shares**
5. All results automatically saved to history
6. Tap **"Go to Calculator Tab"** to proceed with your suggested shares
7. Delete old records by tapping the trash icon next to each history item

---

## 2. **CALCULATOR/SHARES MODULE - Per-Share Cost Customization**

### Features Added:
- ✅ **Custom Per-Share Cost Editor**: For Cow and Camel (not applicable to single Goat)
  - Override the default calculated price
  - Example: If you bought a cow for ৳60,000 and want 2 shares, set per-share cost to ৳30,000
  - Total cost automatically updates when you change shares
  
- ✅ **Cost Breakdown Display**:
  - Shows "You set ৳[price] per share × [shares] share(s)"
  - Clear visual feedback on custom pricing
  
- ✅ **Reset Button**: Easily return to default market prices with one tap

- ✅ **Clearer UI**:
  - Custom per-share section highlighted in light blue
  - Easy-to-spot "Set" button
  - Shows both calculated and custom costs

### How to Use:
1. Go to **Calculators Tab** under Qurbani Cost Planner
2. Select Animal (Cow, Goat, or Camel)
3. Select Location (affects default prices)
4. For Cow/Camel: Select number of shares (1-7)
5. **NEW:** Scroll down to "Custom Per-Share Cost" section
6. Enter your actual per-share price (e.g., ৳30,000)
7. Tap **"Set"** button
8. Total estimated cost updates automatically
9. To reset to defaults, tap **"Reset"** button

### Example Scenario:
- You bought a cow for ৳65,000
- You want to take 2 shares
- Custom per-share cost: ৳32,500
- Enter 32500 in the field and tap Set
- Total estimated cost shows: ৳65,000 (32,500 × 2)

---

## 3. **AQIQAH PLANNER - Cost Editing & Guidelines**

### Features Added:
- ✅ **Editable Aqiqah Estimated Cost**:
  - Edit the cost field directly instead of just viewing it
  - Override default calculations if your local prices differ
  - Example: If local goats cost ৳22,000 instead of ৳25,000, set custom cost
  
- ✅ **Reset Button**: Return to default calculated prices anytime

- ✅ **Detailed Cost Calculation Guidelines**:
  - Clear amber-highlighted section with step-by-step guidance
  - Explains what's included in Aqiqah costs:
    - **For Boys:** 2 animals (usually goats/sheep)
    - **For Girls:** 1 animal (usually goat/sheep)
    - Regional price variations
    - Slaughter costs
    - Butchering and distribution costs
  
- ✅ **Improved Checklist**:
  - Checkboxes now fully functional
  - Track: Baby naming, Hair shaving, Animal purchase, Food distribution
  - Mark items as completed as you go through the Aqiqah process

- ✅ **Better Reminder Integration**:
  - Reminders help you track key Qurbani moments
  - Not just for Qurbani but also guides Aqiqah timeline
  - Can be toggled on/off in Settlements tab

### How to Use - Aqiqah Cost:
1. Go to **Calculators Tab** → **Aqiqah Planner section**
2. Select baby's gender (Boy or Girl)
3. Quantity auto-adjusts (2 for boy, 1 for girl)
4. See **Aqiqah Estimated Cost** with edit field
5. If prices differ from defaults:
   - Enter custom total cost in the text field
   - Tap **"Set"** button
6. Cost updates immediately
7. Use **"Reset"** to return to calculated estimate

### How to Use - Aqiqah Checklist:
1. Scroll down in Aqiqah Planner to see checklist items:
   - Name baby on 7th day
   - Shave baby's hair & give charity
   - Purchase Aqiqah animals
   - Arrange food/distribution
2. Check off items as you complete them
3. All progress is saved automatically

### How to Use - Cost Guidelines:
1. Look for the amber-colored box titled **"💡 Aqiqah Cost Calculation Guide"**
2. Review the guidelines which explain:
   - Number of animals by child gender
   - Regional price variations
   - What costs to include
   - How to estimate full Aqiqah cost

---

## 4. **ELIGIBILITY-CALCULATOR LINK**

### Feature:
- ✅ **Direct Navigation**: After checking eligibility, you now see:
  - Suggested shares based on your net assets
  - **"Go to Calculator Tab"** button
  - Automatically navigate to the calculator and apply suggested share count

### How to Use:
1. Complete eligibility check
2. In result box, see "Suggested Shares for You: [X] share(s)"
3. Tap **"Go to Calculator Tab"** button
4. Automatically redirects to Calculator with your suggested share count

---

## 5. **STATE MANAGEMENT IMPROVEMENTS**

### Technical Changes:
- Added `_eligibilityHistory` list to store up to 10 recent checks
- Added `_suggestedShares` to track recommended share count
- Added `_customPerShareCost` for Qurbani per-share customization
- Added `_customAqiqahCost` for Aqiqah cost customization
- New text controllers: `_perShareCostCtrl` and `_aqiqahCostCtrl`
- Enhanced `_checkEligibility()` method with share calculation logic
- Enhanced `_calculateCosts()` to respect custom per-share pricing
- Enhanced `_calculateAqiqahCosts()` to respect custom total cost
- New method: `_deleteEligibilityRecord(int index)` for history management

---

## 6. **USER EXPERIENCE ENHANCEMENTS**

### Visual Improvements:
- **Eligibility Results Box**: Enhanced to show suggested shares
- **Eligibility History**: Organized list with delete buttons
- **Calculator Section**: Added blue-highlighted custom cost sections
- **Aqiqah Section**: 
  - Amber-colored cost guidelines box
  - Editable cost field with Set/Reset buttons
  - Better visual hierarchy for checklist items

### Clarity Improvements:
- All sections clearly labeled with icons
- Step-by-step guidance for cost calculations
- Visual separation between default and custom pricing
- Color-coded sections (blue for Qurbani, amber for guidelines, teal for Aqiqah)

---

## 7. **KEY BENEFITS**

✅ **Better Decision Making**: See how many shares you need based on wealth

✅ **Flexible Pricing**: Enter your actual costs instead of using estimates

✅ **Cost History**: Keep track of previous eligibility checks

✅ **Clearer Process**: Step-by-step guidelines for both Qurbani and Aqiqah

✅ **Full Control**: Edit every cost field to match your local prices and preferences

✅ **Progress Tracking**: Checklists and reminders to stay on top of preparations

---

## 8. **TESTING CHECKLIST**

When testing these improvements, verify:

- [ ] Eligibility history saves and shows up to 10 items
- [ ] Delete eligibility records works
- [ ] Suggested shares calculate correctly based on net assets
- [ ] Per-share cost editing updates total estimate
- [ ] Reset button returns to default per-share cost
- [ ] Aqiqah cost field is editable
- [ ] Aqiqah cost reset works
- [ ] Aqiqah checklist items toggle on/off properly
- [ ] Guidelines box displays clearly
- [ ] "Go to Calculator Tab" button navigates correctly
- [ ] All text fields accept proper input validation
- [ ] Dark mode displays everything clearly
- [ ] No duplicate history entries
- [ ] Cost calculations are accurate

---

## 9. **NOTES FOR FUTURE ENHANCEMENTS**

Potential improvements for future versions:
- Save eligibility checks to Firestore for cross-device sync
- Add Excel/PDF export of eligibility history
- Create comparison charts for net assets over time
- Add more regional location options with preset prices
- Push notifications for Qurbani/Aqiqah reminders
- Integration with payment tracking for shared costs
- Multilingual support for guidelines
- Video tutorials for Aqiqah and Qurbani processes

---

**End of Improvements Summary**

For questions or issues, please review the code or contact the development team.
