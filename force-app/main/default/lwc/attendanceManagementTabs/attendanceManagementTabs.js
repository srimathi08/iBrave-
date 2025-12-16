/**
 * @description Attendance Management Tabs - Parent Container Component
 * @author Salesforce Consultant
 * @date 2025-11-12
 * @version 1.0 - Initial Release with Tab Navigation
 * 
 * Purpose: Container component that holds two child components in tabs
 * - Tab 1: Admin Attendance View (Daily attendance sheets)
 * - Tab 2: Monthly Attendance Report (Monthly reports with leave integration)
 */

import { LightningElement, track } from 'lwc';

export default class AttendanceManagementTabs extends LightningElement {
    
    // Track active tab (default to first tab)
    @track activeTab = 'attendanceSheets';
    
    /**
     * @description Handle tab change event
     * @param {Event} event - Tab selection event
     */
    handleTabChange(event) {
        // Get the selected tab value
        const selectedTab = event.target.value;
        
        // Update active tab
        this.activeTab = selectedTab;
        
        // Log for debugging
        console.log('Active Tab Changed:', selectedTab);
        
        // Optional: Add custom logic here when tabs change
        // For example: Analytics tracking, loading data, etc.
        if (selectedTab === 'attendanceSheets') {
            console.log('✅ Switched to Attendance Sheets View');
        } else if (selectedTab === 'monthlyReport') {
            console.log('✅ Switched to Monthly Attendance Report View');
        }
    }
    
    /**
     * @description Lifecycle hook - component connected to DOM
     */
    connectedCallback() {
        console.log('=== Attendance Management Tabs Initialized ===');
        console.log('Default Active Tab:', this.activeTab);
    }
}