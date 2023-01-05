//// Copyright (c) 2020 Facebook, Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.



import UIKit
import AVFoundation
import AWAREFramework
import Speech

extension String {
    func stringByAppendingPathComponent(path: String) -> String {
        let s = self as NSString
        return s.appendingPathComponent(path)
    }
}
// https://stackoverflow.com/questions/33821912/implementing-objective-c-delegate-in-swift
class ViewController: UIViewController, AVAudioRecorderDelegate,AWAREAmbientNoiseDelegate  {

    @IBOutlet weak var btnStart: UIButton!
    @IBOutlet weak var btnStop: UIButton!
    @IBOutlet weak var tvResult: UITextView!
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    let manager = AWARESensorManager.shared()
    let core = AWARECore.shared()
    let noiseSensor = AmbientNoise(dbType: AwareDBTypeJSON)
    
    //private var audioRecorder: AVAudioRecorder!
    private var _recorderFilePath: String!
    private var audioFilePath: String = ""
    
    private let AUDIO_LEN_IN_SECOND = 6
    
    private let SAMPLE_RATE = 16000

    private lazy var module: InferenceModule = {
        if let filePath = Bundle.main.path(forResource:
            "wav2vec2", ofType: "ptl"),
            let module = InferenceModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Can't find the model file!")
        }
    }()
    private let lockQueue = DispatchQueue(label: "name.lock.queue");
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // please add following lines to receive update events
        noiseSensor.setSensorEventHandler { sensor, data in
            if let d = data {
                print("core data: \(d)")

            }
        }
//
//        // please add following lines to use raw audio file
//        //url:file:///Users/alisonqiu/Library/Developer/CoreSimulator/Devices/112C1F73-326A-408F-B9CA-2DE6739D60F4/data/Containers/Data/Application/EF727284-B528-47D3-9023-CE0ED3FDCE27/Documents/rawAudioData/14_rawAudio.m4a
//        noiseSensor.setAudioFileGenerationHandler { url in
//            if var audioFilePath = url {
////                print("audioFilePath in view controller \(audioFilePath)")
////                audioFilePath = url?.absoluteURL ?? audioFilePath
//            }
//        }
//
//        // start sensors
//        manager.add(noiseSensor)
//        manager.startAllSensors()
//
//        // for background sensing
//        core.requestPermissionForBackgroundSensing{ state in
//            print(state)
//            self.core.activate()
//        }
        
        
    }
    
    
    
    @IBAction func startTapped(_ sender: Any) {

        noiseSensor.delegate = self
        noiseSensor.saveRawData(true)

        
        //url:file:///Users/alisonqiu/Library/Developer/CoreSimulator/Devices/112C1F73-326A-408F-B9CA-2DE6739D60F4/data/Containers/Data/Application/EF727284-B528-47D3-9023-CE0ED3FDCE27/Documents/rawAudioData/14_rawAudio.m4a
        noiseSensor.setAudioFileGenerationHandler { url in
            if var audioFilePath = url {
//                print("audioFilePath in view controller \(audioFilePath)")
//                audioFilePath = url?.absoluteURL ?? audioFilePath
            }
        }

        // start sensors
        manager.add(noiseSensor)
        //manager.startAllSensors()

        // for background sensing
        core.requestPermissionForBackgroundSensing{ state in
            print(state)
            self.core.activate()
            self.btnStart.setTitle("Listening...", for: .normal)
        }
    }
    
//    func audioDidSave(_ audio_url: URL!) -> String! {
//        //return "mesage from VC"
//        let file = try! AVAudioFile(forReading: audio_url)
//
//        if (file.length == 0){
//            return "file.length is 0"
//        }
//        //file.fileFormat: <AVAudioFormat 0x600001306800:  1 ch,  16000 Hz, Float32>
//        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)
//
//
//        let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))
//
//        try! file.read(into: buf!)
//
//        var floatArray = Array(UnsafeBufferPointer(start: buf?.floatChannelData![0], count:Int(buf!.frameLength)))
//
//        var result = "default";
//        DispatchQueue.global().async {
//
//            floatArray.withUnsafeMutableBytes {
//                //getting result, baseAddress: 0x00007fb87d900020 bufLength:96000
//                result = self.module.recognize($0.baseAddress!, bufLength: Int32(self.AUDIO_LEN_IN_SECOND * self.SAMPLE_RATE))!
//                print("-------result: \(result)")
//                DispatchQueue.main.async {
//                    self.tvResult.text = result
//                    self.btnStart.setTitle("Start", for: .normal)
//                    //TODO: call completion handler
//
//                }
//            }
//        }
//        return result
//    }
    
//    func saveToDB(result:String){
//           let newRes = EntityAmbientNoise(context:self.context);
//           newRes.dnn_res = result;
//           do{
//               try self.context.save()
//               print("self.context.save()")
//           }catch{
//               print("failed self.context.save()")
//           }
//       }
    
    func audioDidSave(_ audio_url: URL!, completion callback: ((String?) -> Void)!) {
                let file = try! AVAudioFile(forReading: audio_url)
        
                if (file.length == 0){
                    return;
                }
                //file.fileFormat: <AVAudioFormat 0x600001306800:  1 ch,  16000 Hz, Float32>
                let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)
        
        
                let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))
        
                try! file.read(into: buf!)
        
                var floatArray = Array(UnsafeBufferPointer(start: buf?.floatChannelData![0], count:Int(buf!.frameLength)))
                var z = floatArray.map {$0}
                z.append(0)
        
                var result = "default";
                //DispatchQueue.global().async {
                    self.lockQueue.async {
                        z.withUnsafeMutableBytes {
                            
                            //getting result, baseAddress: 0x00007fb87d900020 bufLength:96000
                            result = self.module.recognize($0.baseAddress!, bufLength: Int32(self.AUDIO_LEN_IN_SECOND * self.SAMPLE_RATE))!
                            print("-------result: \(result)")
                            
                            DispatchQueue.main.async {
                                self.tvResult.text = result
                                self.btnStart.setTitle("Start", for: .normal)
                                callback(result);
                                
                            }
                        }
                   // }
                }
        
    }
    
    @IBAction func stopTapped(_ sender: Any) {
        core.deactivate();
        self.tvResult.text = "";
        //manager.stopAllSensors();
    }
    
    
    
    
    }

