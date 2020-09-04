//
//  ViewController.swift
//  AudioRecorder
//
//  Created by Paul Solt on 10/1/19.
//  Copyright © 2019 Lambda, Inc. All rights reserved.
//

import UIKit
import AVFoundation

class AudioRecorderController: UIViewController {

    var audioPlayer: AVAudioPlayer? {
        didSet {
            guard let audioPlayer = audioPlayer else {
                return
            }
            audioPlayer.delegate = self
            audioPlayer.isMeteringEnabled = true
        }
    }

    weak var timer: Timer?

    var recordingURL: URL?
    var audioRecorder: AVAudioRecorder?
    
    @IBOutlet var playButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var timeElapsedLabel: UILabel!
    @IBOutlet var timeRemainingLabel: UILabel!
    @IBOutlet var timeSlider: UISlider!
    @IBOutlet var audioVisualizer: AudioVisualizer!
    
    private lazy var timeIntervalFormatter: DateComponentsFormatter = {
        // NOTE: DateComponentFormatter is good for minutes/hours/seconds
        // DateComponentsFormatter is not good for milliseconds, use DateFormatter instead)
        
        let formatting = DateComponentsFormatter()
        formatting.unitsStyle = .positional // 00:00  mm:ss
        formatting.zeroFormattingBehavior = .pad
        formatting.allowedUnits = [.minute, .second]
        return formatting
    }()
    
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Use a font that won't jump around as values change
        timeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeElapsedLabel.font.pointSize,
                                                                 weight: .regular)
        timeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeRemainingLabel.font.pointSize,
                                                                   weight: .regular)
        
        loadAudio()
        updateViews()
    }

    func updateViews() {
        playButton.isSelected = isPlaying

        let elapsedTime = audioPlayer?.currentTime ?? 0
        let duration = audioPlayer?.duration ?? 0
        let timeRemaining = duration.rounded() - elapsedTime

        timeElapsedLabel.text = timeIntervalFormatter.string(from: elapsedTime)
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = Float(duration)
        timeSlider.value = Float(elapsedTime)

        timeRemainingLabel.text = "_" + timeIntervalFormatter.string(from: timeRemaining)!

    }

    deinit {
        timer?.invalidate()
    }
    
    
    // MARK: - Timer
    

     func startTimer() {
     timer?.invalidate()

        // time interval always in seconds
        //whenever have @escaping block, block that sticks around, be very careful about usage of self because it takes up memory... which is why use weak self.
        // change the withTimeInterval to change the refresh display, generally dont go below 30 miliseconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.030, repeats: true) { [weak self] (_) in
       //guard let deals with escaping blocks, so return before do anything
     guard let self = self else { return }

     self.updateViews()
/*
     if let audioRecorder = self.audioRecorder,
     self.isRecording == true {

     audioRecorder.updateMeters()
     self.audioVisualizer.addValue(decibelValue: audioRecorder.averagePower(forChannel: 0))

     }
*/
     if let audioPlayer = self.audioPlayer,
     self.isPlaying == true {

     audioPlayer.updateMeters()
     self.audioVisualizer.addValue(decibelValue: audioPlayer.averagePower(forChannel: 0))
     }
     }
     }

     func cancelTimer() {
       //invalidate doesnt set property to nil, but keeps the timer from running
     timer?.invalidate()
     timer = nil
     }

    
    
    // MARK: - Playback

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
    
    func loadAudio() {
        let songURL = Bundle.main.url(forResource: "piano", withExtension: "mp3")!
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: songURL)
        } catch {
            preconditionFailure("Failure to load audio file: \(error)")
        }
    }
    

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true, options: []) // can fail if on a phone call, for instance
    }

    
    func play() {
        do {
            try prepareAudioSession()
            audioPlayer?.play()
            updateViews()
            startTimer()
        } catch {
            print("Cannot play audio: \(error)")
        }

        
    }
    
    func pause() {
        audioPlayer?.pause()
        updateViews()
        cancelTimer()
    }
    
    
    // MARK: - Recording

    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    func createNewRecordingURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let name = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: .withInternetDateTime)
        let file = documents.appendingPathComponent(name, isDirectory: false).appendingPathExtension("caf")
        
                print("recording URL: \(file)")
        
        return file
    }
    

     func requestPermissionOrStartRecording() {
     switch AVAudioSession.sharedInstance().recordPermission {
     case .undetermined:
     AVAudioSession.sharedInstance().requestRecordPermission { granted in
     guard granted == true else {
     print("We need microphone access")
     return
     }

     print("Recording permission has been granted!")
     // NOTE: Invite the user to tap record again, since we just interrupted them, and they may not have been ready to record
     }
     case .denied:
     print("Microphone access has been blocked.")

     let alertController = UIAlertController(title: "Microphone Access Denied", message: "Please allow this app to access your Microphone.", preferredStyle: .alert)

     alertController.addAction(UIAlertAction(title: "Open Settings", style: .default) { (_) in
     UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
     })

     alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))

     present(alertController, animated: true, completion: nil)
     case .granted:
     startRecording()
     @unknown default:
     break
     }
     }

    
    func startRecording() {
        do {
            try prepareAudioSession()
        } catch {
            print("Cannot record audio: \(error)")
            return
        }

        recordingURL = createNewRecordingURL()

        //can return option because you can give it invalid format and combinations
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, format: format)
            audioRecorder?.record()
        } catch {
            preconditionFailure("The audio recorder could not be created with \(recordingURL!) and \(format)")
        }
        
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }
    
    // MARK: - Actions
    
    @IBAction func togglePlayback(_ sender: Any) {
        if isPlaying {
            pause()
        } else {
            play()
        }
        
    }
    
    @IBAction func updateCurrentTime(_ sender: UISlider) {
        if isPlaying {
            pause()
        }
        audioPlayer?.currentTime = TimeInterval(sender.value)
        updateViews()
    }
    
    @IBAction func toggleRecording(_ sender: Any) {
        if isRecording {
                  stopRecording()
              } else {
                  requestPermissionOrStartRecording()
              }
    }
}

extension AudioRecorderController: AVAudioPlayerDelegate {

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateViews()
        cancelTimer()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio Player Error: \(error)")
        }
    }
}

