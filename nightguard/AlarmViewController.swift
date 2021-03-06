//
//  AlarmViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 03.05.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class AlarmViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var noDataAlarmOptions = ["15 Minutes", "20 Minutes", "25 Minutes", "30 Minutes", "35 Minutes", "40 Minutes", "45 Minutes"]
    
    fileprivate let MAX_ALERT_ABOVE_VALUE : Float = 200
    fileprivate let MIN_ALERT_ABOVE_VALUE : Float = 80
    
    fileprivate let MAX_ALERT_BELOW_VALUE : Float = 150
    fileprivate let MIN_ALERT_BELOW_VALUE : Float = 50
    
    @IBOutlet weak var edgeDetectionSwitch: UISwitch!
    @IBOutlet weak var numberOfConsecutiveValues: UITextField!
    @IBOutlet weak var deltaAmount: UITextField!
    
    @IBOutlet weak var alertIfAboveValueLabel: UILabel!
    @IBOutlet weak var alertIfBelowValueLabel: UILabel!
    
    @IBOutlet weak var alertAboveSlider: UISlider!
    @IBOutlet weak var alertBelowSlider: UISlider!
    
    @IBOutlet weak var unitsLabel: UILabel!
    
    @IBOutlet weak var noDataAlarmButton: UIButton!
    @IBOutlet weak var noDataAlarmPickerView: UIPickerView!
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        updateUnits()
        
        edgeDetectionSwitch.isOn = (defaults?.bool(forKey: "edgeDetectionAlarmEnabled"))!
        numberOfConsecutiveValues.text = defaults?.string(forKey: "numberOfConsecutiveValues")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(AlarmViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
        
        noDataAlarmPickerView.delegate = self
        noDataAlarmPickerView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        updateUnits()
        
        deltaAmount.text = UnitsConverter.toDisplayUnits((defaults?.string(forKey: "deltaAmount"))!)
        
        alertIfAboveValueLabel.text = UnitsConverter.toDisplayUnits((defaults?.string(forKey: "alertIfAboveValue"))!)
        alertAboveSlider.value = (UnitsConverter.toMgdl(alertIfAboveValueLabel.text!.floatValue) - MIN_ALERT_ABOVE_VALUE) / MAX_ALERT_ABOVE_VALUE
        alertIfBelowValueLabel.text = UnitsConverter.toDisplayUnits((defaults?.string(forKey: "alertIfBelowValue"))!)
        alertBelowSlider.value = (UnitsConverter.toMgdl(alertIfBelowValueLabel.text!.floatValue) - MIN_ALERT_BELOW_VALUE) / MAX_ALERT_ABOVE_VALUE
        
        noDataAlarmButton.setTitle(defaults?.string(forKey: "noDataAlarmAfterMinutes"), for: UIControlState())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    @IBAction func edgeDetectionSwitchChanged(_ sender: AnyObject) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(edgeDetectionSwitch.isOn, forKey: "edgeDetectionAlarmEnabled")
        AlarmRule.isEdgeDetectionAlarmEnabled = edgeDetectionSwitch.isOn
    }
    
    @IBAction func valuesEditingChanged(_ sender: AnyObject) {
        guard let numberOfConsecutiveValues = Int(numberOfConsecutiveValues.text!)
        else {
            return
        }
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(numberOfConsecutiveValues, forKey: "numberOfConsecutiveValues")
        AlarmRule.numberOfConsecutiveValues = numberOfConsecutiveValues
    }
    
    @IBAction func deltaEditingChanged(_ sender: AnyObject) {
        let deltaAmountValue = UnitsConverter.toMgdl(deltaAmount.text!)
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(deltaAmountValue, forKey: "deltaAmount")
        AlarmRule.deltaAmount = deltaAmountValue
    }
    
    @IBAction func aboveAlertValueChanged(_ sender: AnyObject) {
        let alertIfAboveValue = getAboveAlarmValue()
        adjustLowerSliderValue()
        alertIfAboveValueLabel.text = UnitsConverter.toDisplayUnits(String(alertIfAboveValue))
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(alertIfAboveValue, forKey: "alertIfAboveValue")
        
        AlarmRule.alertIfAboveValue = alertIfAboveValue
        WatchService.singleton.sendToWatch(UnitsConverter.toMgdl(alertIfBelowValueLabel.text!), alertIfAboveValue: alertIfAboveValue)
    }
    
    @IBAction func belowAlertValueChanged(_ sender: AnyObject) {
        let alertIfBelowValue = getBelowAlarmValue()
        adjustAboveSliderValue()
        alertIfBelowValueLabel.text = UnitsConverter.toDisplayUnits(String(alertIfBelowValue))
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(alertIfBelowValue, forKey: "alertIfBelowValue")
        
        AlarmRule.alertIfBelowValue = alertIfBelowValue
        WatchService.singleton.sendToWatch(alertIfBelowValue, alertIfAboveValue: UnitsConverter.toMgdl(alertIfAboveValueLabel.text!))
    }
    
    func getAboveAlarmValue() -> Float {
        return Float(MIN_ALERT_ABOVE_VALUE + alertAboveSlider.value * MAX_ALERT_ABOVE_VALUE)
    }
    
    func getBelowAlarmValue() -> Float {
        return Float(MIN_ALERT_BELOW_VALUE + alertBelowSlider.value * MAX_ALERT_BELOW_VALUE)
    }
    
    func adjustLowerSliderValue() {
        if getAboveAlarmValue() - getBelowAlarmValue() < 1 {
            alertBelowSlider.setValue(
                (getAboveAlarmValue() - 1 - MIN_ALERT_BELOW_VALUE) / MAX_ALERT_BELOW_VALUE, animated: true)
            belowAlertValueChanged(alertBelowSlider)
        }
    }
    
    func adjustAboveSliderValue() {
        if getBelowAlarmValue() - getAboveAlarmValue() > 0 {
            alertAboveSlider.setValue(
                (getBelowAlarmValue() + 1 - MIN_ALERT_ABOVE_VALUE) / MAX_ALERT_ABOVE_VALUE, animated: true)
            aboveAlertValueChanged(alertAboveSlider)
        }
    }
    
    func updateUnits() {
        let units = UserDefaultsRepository.readUnits()
        
        if units == Units.mmol {
            unitsLabel.text = "mmol"
        } else {
            unitsLabel.text = "mg/dL"
        }
    }
    
    // Remove keyboard and PickerView by touching outside
    func onTouchGesture(){
        self.view.endEditing(true)
        self.noDataAlarmPickerView.isHidden = true
    }
    
    
    // Methods for the noDataAlarmPickerView
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return noDataAlarmOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return noDataAlarmOptions.count
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    @IBAction func noDataAlarmButtonPressed(_ sender: AnyObject) {
        preselectItemInPickerView()
        noDataAlarmPickerView.isHidden = false
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedMinutes = toButtonText(noDataAlarmOptions[row])
        noDataAlarmButton.setTitle(selectedMinutes, for: UIControlState())
        
        // Remember the selected value by storing it as default setting
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(selectedMinutes, forKey: "noDataAlarmAfterMinutes")
        
        // Activate the new AlarmRule
        AlarmRule.minutesWithoutValues = Int(selectedMinutes)!
    }
    
    // Selects the right item that is shown in the noDataAlarmButton in the PickerView
    fileprivate func preselectItemInPickerView() {
        let rowOfSelectedItem : Int = noDataAlarmOptions.index(of: noDataAlarmButton.currentTitle! + " Minutes")!
        noDataAlarmPickerView.selectRow(rowOfSelectedItem, inComponent: 0, animated: false)
    }
    
    fileprivate func toButtonText(_ pickerText : String) -> String {
        return pickerText.replacingOccurrences(of: " Minutes", with: "")
    }
}
