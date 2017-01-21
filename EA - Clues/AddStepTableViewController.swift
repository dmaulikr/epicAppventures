//
//  AddStepTableViewController.swift
//  MapPlay
//
//  Created by James Birtwell on 19/12/2015.
//  Copyright © 2015 James Birtwell. All rights reserved.
//

import UIKit
import GooglePlacePicker
import CoreLocation
import AVFoundation

protocol AddStepTableViewControllerDelegate: NSObjectProtocol  {
    
    func updateAppventureLocation(_ location: CLLocation)
}

struct PlaceCache {
    let name: String?
    let coordinate : CLLocation
    let address: String
    
    init (step: AppventureStep) {
        self.name = step.nameOrLocation
        self.coordinate = step.location!
        self.address = step.locationSubtitle
    }
    
    init (place: GMSPlace) {
        self.name = place.name
        let coordinate = place.coordinate
        self.coordinate = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let formAddr = place.formattedAddress {
            self.address = formAddr
        } else {
            self.address = ""
        }
    }
}


class AddStepTableViewController: UITableViewController, UITextFieldDelegate, UITextViewDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate
{
    struct Constants {
        static let AddAnswer = "AddAnswer"
        static let AddHint = "AddHint"
        static let locationSettingsSegue = "locationSettingsSegue"
        static let ImageChooser = "ImageChooser"
        static let EditTextClue = "EditTextClue"

    }
    
    //MARK: Model
    var appventureStep = AppventureStep()
    var lastLocation: CLLocation?
    var soundDataCache: Data?
    var placeCache: PlaceCache?
    
    weak var delegate: AddStepTableViewControllerDelegate?
    //Sound
    var soundFileURL = URL(fileURLWithPath: "") //cache?
    var totalLength = 0.0 { didSet { if let formattedTime = HelperFunctions.formatTime(ms, nano: false) {
        totalLengthLabel.text = formattedTime
        } } }
    //Process Elements
    var placePicker: GMSPlacePicker!
    var recorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    //Timer
    var timer: Timer!
    var ms = 0.0 { didSet { if let formattedTime = HelperFunctions.formatTime(ms, nano: false) {
        soundLabel.text = formattedTime
        } } }
    //MARK: Outlets
    
    //TableCells
    @IBOutlet weak var locationSettingsCell: UITableViewCell!
    @IBOutlet weak var locationNameCell: UITableViewCell!
    @IBOutlet weak var TextClueCell: UITableViewCell!
    @IBOutlet weak var pictureViewCell: UITableViewCell!
    @IBOutlet weak var soundClueCell: UITableViewCell!
    //Nav Buttons
    @IBOutlet weak var saveButton: UIBarButtonItem!
    //Section 0 - Location
    @IBOutlet weak var locationSwitch: UISwitch!
    @IBOutlet weak var locationNameLabel: UILabel!
    @IBOutlet weak var locationSetupDetails: UILabel!
    //section 1 - Clues
    @IBOutlet weak var stepThumbnail: UIImageView!
    @IBOutlet weak var initialTextLabel: UILabel!

    @IBOutlet weak var intialTextSwitch: UISwitch!
    @IBOutlet weak var soundSwitch: UISwitch!
    @IBOutlet weak var pictureSwitch: UISwitch!
    
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet weak var totalLengthLabel: UILabel!

    //section 2 - Answer
    @IBOutlet weak var checkInControl: UISegmentedControl!
    @IBOutlet weak var answersLabel: UILabel!
    @IBOutlet weak var checkInLabel: UILabel!
    @IBOutlet weak var checkInTextField: UITextField!
    
    //section 3 - Hints
    @IBOutlet weak var freeHintsTextField: UITextField!
    @IBOutlet weak var hintsLabel: UILabel!
    @IBOutlet weak var hintPenalty: UITextField!
    
    //section 4 - Completion
    @IBOutlet weak var completionTextView: UITextView!
    
    //MARK: View Controller Lifecycle
    override func viewDidLoad() {
        checkInTextField.delegate = self
        completionTextView.delegate = self
        freeHintsTextField.delegate = self
        
        recorderSetUp()
        saveButton.isEnabled = false

        setCaches()
        
        initialUISetup()
    }
    
    override func viewDidAppear(_ animated: Bool)  {
        updatePartUI()
        checkSaveButton()
    }
    
    
    func setCaches() {
        soundDataCache = appventureStep.sound as Data?
        placeCache = PlaceCache(step: appventureStep)
    }
    
    //MARK: Update UI
    func updatePartUI () {
        //section0 - Location
        if let place = placeCache  {
            self.locationNameLabel.text = place.name
        } else {
            self.locationNameLabel.text = "Set Location..."
        }
        

        var locationSetupString = [String]()
        appventureStep.setup.locationShown ?  locationSetupString.append("Location on map") : locationSetupString.append("No location on map")
        appventureStep.setup.compassShown ? locationSetupString.append("Show direction") : locationSetupString.append("No direction")
        appventureStep.setup.distanceShown ?  locationSetupString.append("Show distance") : locationSetupString.append("No distance")
        locationSetupDetails.text = locationSetupString.joined(separator: ",")
        
        //section1 - Clues
              appventureStep.initialText == "" ? (initialTextLabel.text = "Set instructions...") : (initialTextLabel.text = appventureStep.initialText)
        
        //ImageView
        if let image = appventureStep.image {
            stepThumbnail.image = image
        }
        
        //section2 - Answer
        self.checkInLabel.text = self.locationNameLabel.text
        appventureStep.answerText.count == 0 ? (self.answersLabel.text = "Set answers...") :
            (self.answersLabel.text = "Answers availabe: \(appventureStep.answerText.count)")
        
        //section3 - Hints
        self.appventureStep.answerHint.count == 0 ? (self.hintsLabel.text = "Set hints...") : (self.hintsLabel.text = "Hints availabe: \(appventureStep.answerHint.count)")
        
    }
    
    func initialUISetup () {
        let stepNumber = String(appventureStep.stepNumber)
        self.navigationItem.title = ("Step: \(stepNumber)")
        
        
        //section1 - Clues
        soundSwitch.isOn = appventureStep.setup.soundClue
        pictureSwitch.isOn = appventureStep.setup.pictureClue
        intialTextSwitch.isOn = appventureStep.setup.textClue
        //SoundView
        if let soundData = soundDataCache {
            do {
                audioPlayer = try AVAudioPlayer(data: soundData)
                totalLength = audioPlayer.duration
                totalLengthLabel.text = HelperFunctions.formatTime(totalLength, nano: false)
                audioPlayer.delegate = self
                //TODO: enable playButton
            }
            catch let error as NSError {
                print(error.localizedDescription)
            }
            
        }
        
        //section2 - Answer
        self.appventureStep.setup.checkIn == true ? (self.checkInControl.selectedSegmentIndex = 0) : (self.checkInControl.selectedSegmentIndex = 1)
        self.checkInTextField.text = String(appventureStep.checkInProximity)

        
        //section3 - Hints
        self.appventureStep.answerHint.count == 0 ? (self.hintsLabel.text = "Set hints...") : (self.hintsLabel.text = "Hints availabe: \(appventureStep.answerHint.count)")
        self.freeHintsTextField.text = String(appventureStep.freeHints)
        self.hintPenalty.text = String(appventureStep.hintPenalty)
        
        //section4 - Completion Text
        self.completionTextView.text = appventureStep.completionText
        
        self.updatePartUI()
        
        //Size cells
        sizeTableCells()
    }
    
    var loaded = false
    
    func sizeTableCells() {
        if pictureViewCell != nil {
            loaded = true
        }
        self.tableView.reloadData()
    }

    
    func checkSaveButton() {
        var enableSave = true
        
        if placeCache == nil {
            enableSave = false
        }

        if soundSwitch.isOn == false && pictureSwitch.isOn == false && intialTextSwitch.isOn == false {
            enableSave = false
        }
        
        if soundSwitch.isOn  == true {
            if soundDataCache == nil {
                enableSave = false
            }
        }
        if pictureSwitch.isOn == true {
            if appventureStep.image == nil {
                enableSave = false
            }
        }
        if intialTextSwitch.isOn == true {
            if appventureStep.initialText == "" {
                enableSave = false
            }
        }
        
        if self.checkInControl.selectedSegmentIndex == 1 {
            if appventureStep.answerText.count == 0 {
                enableSave = false
            }
        }
        
        if enableSave == true {
            saveButton.isEnabled = true
        } else {
            saveButton.isEnabled = false
        }
    }
    
    //MARK: IB Actions
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        AppDelegate.coreDataStack.rollbackContext()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func save(_ sender: AnyObject) {
        
        updateStep()
        
        if appventureStep.stepNumber == 1 {
            delegate?.updateAppventureLocation(appventureStep.location!)
        }
        
        AppDelegate.coreDataStack.saveContext(completion: nil)
        
        self.dismiss(animated: true, completion: nil)

    }
    
    func updateStep() {
        //add in all step sections here 
        if let penalty = Int16(self.hintPenalty.text!) { self.appventureStep.hintPenalty = penalty }
        if let freeHints = Int16(self.freeHintsTextField.text!) { self.appventureStep.freeHints = freeHints }
        if checkInControl.selectedSegmentIndex == 0 {
            appventureStep.setup.checkIn = true
        } else {
            appventureStep.setup.checkIn = false
        }
        appventureStep.setup.soundClue = soundSwitch.isOn
        appventureStep.setup.pictureClue = pictureSwitch.isOn
        appventureStep.setup.textClue = intialTextSwitch.isOn
        if let distanceText = checkInTextField.text {
            if let distance = Int16(distanceText) {
                appventureStep.checkInProximity = distance
            }
        }
        if let hintNumberText = freeHintsTextField.text {
            if let freeHintsInt = Int16(hintNumberText) {
                appventureStep.freeHints = freeHintsInt
            }
        }
        
        self.appventureStep.completionText = self.completionTextView.text
        self.appventureStep.sound = soundDataCache
        self.appventureStep.location = placeCache!.coordinate
        self.appventureStep.nameOrLocation = placeCache!.name
        self.appventureStep.locationSubtitle = placeCache!.address
        
    }
    
    
    //MARK: Boolean Functions
    
    @IBAction func locationSwitched(_ sender: UISwitch) {
        tableView.reloadData()
        checkSaveButton()
    }
    
    @IBAction func soundSwitched(_ sender: UISwitch) {
        tableView.reloadData()
        checkSaveButton()
    }
    
    @IBAction func pictureSwitched(_ sender: UISwitch) {
        tableView.reloadData()
        checkSaveButton()
    }
    
    @IBAction func textSwitched(_ sender: UISwitch) {
        TextClueCell.isHidden = !sender.isOn
        tableView.reloadData()

        checkSaveButton()
    }
    
    @IBAction func checkInControl(_ sender: UISegmentedControl) {
        tableView.reloadData()
        checkSaveButton()
    }


    //MARK: TextField Delegates
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        checkSaveButton()
    }
    
    //MARK: TextView Delegates
    
    func textViewDidEndEditing(_ textView: UITextView) {
        checkSaveButton()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    //MARK: Add/Play Sound
    
    func recorderSetUp() {
        
        //init
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        
        //ask for permission
        if (audioSession.responds(to: #selector(AVAudioSession.requestRecordPermission(_:)))) {
            AVAudioSession.sharedInstance().requestRecordPermission({(granted: Bool)-> Void in
                if granted {
                    print("granted")
                    
                    //set category and activate recorder session
                    try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
                    try! audioSession.setActive(true)
        
        let currentFileName = ("temp.caf")
        let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let docsDir: AnyObject = dirPaths[0] as AnyObject
//        let soundFilePath = docsDir.appendingPathComponent(currentFileName)
        let soundFilePath = docsDir.appending(currentFileName)
        self.soundFileURL = URL(fileURLWithPath: soundFilePath)
//        appventureStep.sound?.writeToURL(soundFileURL, atomically: true)
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: soundFilePath) {
            print("sound exists")
        }
        
        let recordSettings = [
            AVFormatIDKey: NSNumber(value: kAudioFormatAppleIMA4 as UInt32),
            AVEncoderAudioQualityKey : AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey : 320,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey : 440.0
        ] as [String : Any]
        
        do {
            self.recorder = try AVAudioRecorder(url: self.soundFileURL, settings: recordSettings)
            self.recorder.delegate = self
            self.recorder.isMeteringEnabled = true
            self.recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        } catch let error as NSError {
            self.recorder = nil
            print(error.localizedDescription)
        }
                    
                } else{
                    print("not granted")
                }
            })
        
        }
    }
    
    @IBAction func stopSound(_ sender: AnyObject) {
        
        if recorder.isRecording == true {
            recorder.stop()
            totalLength = ms
            
            soundDataCache = try? Data(contentsOf: soundFileURL)
            ms = 0
            self.timer.invalidate()
            self.timer = nil

        }
        
        if audioPlayer != nil {
            if audioPlayer.isPlaying == true  {
                audioPlayer.stop()
                ms = 0
                self.timer.invalidate()
                self.timer = nil
            }
            
        }
        
        checkSaveButton()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        ms = 0
        self.timer.invalidate()
        self.timer = nil
    }

    @IBAction func record(_ sender: UIButton) {
        if !recorder.isRecording {
        recorder.record()
        startTimer()
        }
    
    }
    
    @IBAction func playSound(_ sender: UIButton) {
        
        if audioPlayer == nil {
            if let soundData = soundDataCache as Data! {
                do {
                        self.audioPlayer = try AVAudioPlayer(data: soundData)
                        self.audioPlayer.play()
                        self.startTimer()
                        self.audioPlayer.delegate = self
                }
                catch let error as NSError {
                    //
                    print(error.localizedDescription)
                }
            }
        } else {
            if !audioPlayer.isPlaying {
                self.audioPlayer.play()
                self.startTimer()
            }
        }
        
        
        
    }
    
    //MARK: Timer
    
    func startTimer() {
        timer = Timer.init()
        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(AddStepTableViewController.update), userInfo: nil, repeats: true)

//        self.timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(AddStepTableViewController.update), userInfo: nil, repeats: true)
    }
    
    func update() {
        //if audioPlayer.playing == true || recorder.recording == true {
        self.ms += 1
        //  }
    }

    
    //MARK: GMS Picker
    func pickLocation() {
        var center: CLLocationCoordinate2D?
        
        if let currentCoordinate = lastLocation?.coordinate as CLLocationCoordinate2D! {
             center = CLLocationCoordinate2DMake(currentCoordinate.latitude, currentCoordinate.longitude)
        } else {
             center = CLLocationCoordinate2DMake(0, 0)
        }
        
        let northEast = CLLocationCoordinate2DMake(center!.latitude + 0.001, center!.longitude + 0.001)
        let southWest = CLLocationCoordinate2DMake(center!.latitude - 0.001, center!.longitude - 0.001)
        
        let viewport = GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
        let config = GMSPlacePickerConfig(viewport: viewport)
        placePicker = GMSPlacePicker(config: config)
    
        placePicker.pickPlace(callback: { (place, error) in
            if let error = error {
                print("Pick Place error: \(error.localizedDescription)")
                return
            }
            if let place = place {
                self.placeCache = PlaceCache(place: place)
            } else {
                print("No place selected")
            }
        })
    }

    //MARK: Navigation
    
    func locationSettings() {
        performSegue(withIdentifier: Constants.locationSettingsSegue, sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.locationSettingsSegue {
            if let lstvc = segue.destination as? LocationSettingsTableViewController  {
                lstvc.step = self.appventureStep
            }
        }
        if segue.identifier == Constants.ImageChooser {
            if let icvc = segue.destination as? ImageChooserViewController {
                icvc.step = self.appventureStep
            }
        }
        if segue.identifier == Constants.EditTextClue {
            if let etvc = segue.destination as? EditTextClueViewController {
                etvc.step = self.appventureStep
            }
        }
        if segue.identifier == Constants.AddAnswer {
            if let aatvc = segue.destination as? AddAnswerTableViewController {
                aatvc.step = self.appventureStep
            }
        }
        if segue.identifier == Constants.AddHint {
            if let ahtvc = segue.destination as? AddHintTableViewController {
                ahtvc.step = self.appventureStep
            }
        }
  
    }
    
//    MARK: Table Methods
    
    
    let locationButton = IndexPath(row: 0, section: 0)
    let pickLocationPath = IndexPath(row: 1, section: 0)
    let locationSettingsPath = IndexPath(row: 2, section: 0)
    let intitalTextPath = IndexPath(row: 1, section: 1)
    let imagePath = IndexPath(row: 3, section: 1)
    let soundPath = IndexPath(row: 5, section: 1)
    let textAnswerArray = IndexPath(row: 1, section: 2)
    let checkInLocation = IndexPath(row: 2, section: 2)
    let checkInDistance = IndexPath(row: 3, section: 2)
    let hintArray = IndexPath(row: 0, section: 3)
    let completion = IndexPath(row: 0, section: 4)




    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == locationNameCell {
            self.pickLocation()
        }
    }
        override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            var float:CGFloat = 44.0
            

            
            switch indexPath {
            case locationButton:
                float = 0.0
            case pickLocationPath:
                self.locationSwitch.isOn ?  (float = 44.0) : (float = 0.0 )
            case locationSettingsPath:
                self.locationSwitch.isOn ?  (float = 44.0) : (float = 0.0 )
            case intitalTextPath:
                self.intialTextSwitch.isOn ?( float = 44.0) : (float = 0.0 )
            case imagePath:
                self.pictureSwitch.isOn ? (float = 132.0) : (float = 0.0 )
            case soundPath:
                self.soundSwitch.isOn ? (float = 88.0) : (float = 0.0 )
            case textAnswerArray:
                self.checkInControl.selectedSegmentIndex == 1 ? (float = 44) : (float = 0.0 )
            case checkInLocation:
                self.checkInControl.selectedSegmentIndex == 0 ? (float = 44) : (float = 0.0 )
            case checkInDistance:
                self.checkInControl.selectedSegmentIndex == 0 ? (float = 44) : (float = 0.0 )
            case completion:
                float = 132
            default:
                break
            }
            
            
            
            return float
        }
            
    
//    
//    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return 44
//    }
//    
//    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//        let title = sections(rawValue: section)?.footerTitle()
//        let button = sections(rawValue: section)?.footerButton(self, footerFrame: CGRect(), tableView: tableView)
//        if title == nil && button == nil {
//            return 0
//        } else {
//            return 30
//        }
//    }
//    
//    enum sections: Int {
//        case location = 0
//        case clues
//        case answer
//        case completion
//        case other
//        
//        func headerTitle() -> UILabel? {
//            let cgRect = CGRect(x: 10, y: 10, width: 200, height: 30)
//            let title = UILabel(frame: cgRect)
//            title.font = UIFont.boldSystemFontOfSize(14.0)
////            title.textColor = UIColor
//            switch self {
//            case .location:
//                title.text = "Set Location"
//                return title
//            case .clues:
//                title.text = "Clues (min 1):"
//                return title
//            case .answer:
//                title.text = "Answer or Checkin:"
//                return title
//            case .completion:
//                title.text = "Completion Page:"
//                return title
//            case .other:
//                title.text = "Tags"
//                return title
//            }
//        }
//        
//        func headerButton(vc: AnyObject?, headerFrame: CGRect, tableView: UITableView) -> UIButton? {
//            let headBttn:UIButton = UIButton(type: UIButtonType.Custom) as UIButton
//            headBttn.frame = CGRectMake(headerFrame.size.width - 200, 10, 170, 30)
//            headBttn.setTitleColor(headBttn.tintColor, forState: UIControlState.Normal)
//            headBttn.titleLabel?.font = UIFont(name: "Helvetica", size: 12)
//            headBttn.enabled = true
//            headBttn.contentHorizontalAlignment = UIControlContentHorizontalAlignment.Right
//            switch self {
//            case .location:
//                headBttn.setTitle("Pick ->", forState: UIControlState.Normal)
//                headBttn.addTarget(vc, action: #selector(AddStepTableViewController.pickLocation(_:)), forControlEvents: UIControlEvents.TouchUpInside)
////                headBttn.tag = 
//                return headBttn
//            default:
//                return nil
//            }
//        }
//        
//        func footerTitle() -> UILabel? {
//            return nil
//        }
//        
//        func footerButton(vc: AnyObject?, footerFrame: CGRect, tableView: UITableView) -> UIButton? {
//            let bttn:UIButton = UIButton(type: UIButtonType.Custom) as UIButton
//            bttn.frame = CGRectMake(footerFrame.size.width - 200, 10, 170, 30)
//            bttn.setTitleColor(bttn.tintColor, forState: UIControlState.Normal)
//            bttn.titleLabel?.font = UIFont(name: "Helvetica", size: 12)
//            bttn.enabled = true
//            bttn.contentHorizontalAlignment = UIControlContentHorizontalAlignment.Right
//            switch self {
//                case .location:
//                bttn.setTitle("location Settings->", forState: UIControlState.Normal)
//                bttn.addTarget(vc, action: #selector(AddStepTableViewController.locationSettings), forControlEvents: UIControlEvents.TouchUpInside)
//                return bttn
//                default:
//                return nil
//            }
//
//        }
//    }
//    
//    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let headerFrame:CGRect = tableView.frame
//        
//        let titleLabel = sections(rawValue: section)?.headerTitle()
//        let headerButton = sections(rawValue: section)?.headerButton(self, headerFrame: headerFrame, tableView: tableView)
//        
//        let headerView:UIView = UIView(frame: CGRectMake(0, 0, headerFrame.size.width, headerFrame.size.height))
////        headerView.backgroundColor = UIColor(red: 108/255, green: 185/255, blue: 0/255, alpha: 0.9)
//        
//        if let isTitle = titleLabel as UILabel! {
//            headerView.addSubview(isTitle)
//        }
//        if let headBttn = headerButton as UIButton! {
//            headerView.addSubview(headBttn)
//        }
//
//        return headerView
//
//    }
//    
//    
//    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
//        let footerFrame:CGRect = tableView.frame
//        
//        let titleLabel = sections(rawValue: section)?.footerTitle()
//        let footerButton = sections(rawValue: section)?.footerButton(self, footerFrame: footerFrame, tableView: tableView)
//        
//        let headerView:UIView = UIView(frame: CGRectMake(0, 0, footerFrame.size.width, footerFrame.size.height))
//        //        headerView.backgroundColor = UIColor(red: 108/255, green: 185/255, blue: 0/255, alpha: 0.9)
//        
//        if let isTitle = titleLabel as UILabel! {
//            headerView.addSubview(isTitle)
//        }
//        if let footBttn = footerButton as UIButton! {
//            headerView.addSubview(footBttn)
//        }
//        
//        return headerView
//    }
    
 

    
}





