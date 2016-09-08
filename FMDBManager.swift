//
//  FMDBManager.swift
//  babyCam
//
//  Created by 王立诚 on 16/6/2.
//  Copyright © 2016年 oyc. All rights reserved.
//

import UIKit
import FMDB

class FMDBManager: NSObject {
    
    var uid = "";
    
    //数据库队列对象
    var dbQueue : FMDatabaseQueue?
    
    //摄像头表名称
    static let monitorTable = "t_monitor"
    
    //设备表名称
    static let devTable = "Devices";
    //时光机时间表名称
    static let timeMachineTable = "t_timeMachine";
    //日志表名称
    static let monitorLogTable = "MonitorLog";
    
    //! 单例接口
    class func shareInstance() ->FMDBManager {
        //! 定义内部单例对象
        struct Singleton {
            static var predicate : dispatch_once_t = 0;
            static var instance : FMDBManager? = nil;
        }
        //! 保证线程安全，以及只会被调用一次
        dispatch_once(&Singleton.predicate, { () -> Void in
            Singleton.instance = FMDBManager();
            Singleton.instance?.openDB();
            print("create db success");
        })
        
        return Singleton.instance!;
    }
    
    deinit {
        self.dbQueue?.close();
    }
    
    //2.打开数据库
    func openDB() {
        
        //2.1获取数据库存放的路径
        let basePath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first
        let filePath = basePath?.stringByAppendingString("/" + "smileHome")
        
        //2.2创建数据库,FMDatabaseQueue返回一个数据库队列,保证线程安全
        dbQueue = FMDatabaseQueue(path: filePath)
        print(basePath)
        
        //2.3创建表
        self.createTable("CREATE TABLE IF NOT EXISTS \(FMDBManager.monitorTable) ('file_id' INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, 'filePath' TEXT, 'camera_id' TEXT, 'fileType' TEXT, 'time' TEXT, 'userName' TEXT)");
        self.createTable("CREATE TABLE IF NOT EXISTS \(FMDBManager.devTable) (id integer PRIMARY KEY AUTOINCREMENT, uid text, nickname text, account text, password text, channel text, connect text, sound text, stream text, pushallow bool, optMode integer)");
        self.createTable("CREATE TABLE IF NOT EXISTS \(FMDBManager.timeMachineTable) (id integer PRIMARY KEY AUTOINCREMENT, date text, mark boolean, photoPath text, photoDsc text)");
        self.createTable("CREATE TABLE IF NOT EXISTS \(FMDBManager.monitorLogTable) (id integer PRIMARY KEY AUTOINCREMENT, devId text, type text, time double, picture text)");
    }
    
    func setupUser(user: String) {
        
        let notAllowedCharactersSet = NSCharacterSet(charactersInString: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdedghijklmnopqrsquvwxyz").invertedSet
        self.uid = (user.md5().componentsSeparatedByCharactersInSet(notAllowedCharactersSet) as NSArray).componentsJoinedByString("")
        print("self.uid = \(self.uid)")
        self.createTable("CREATE TABLE IF NOT EXISTS \(self.uid) (id integer PRIMARY KEY AUTOINCREMENT, name text, sexual bool, birthday text, tcode text)");
    }

    private func createTable(createTableCode : String) {
    
        //3.1 拼接创建表的语句
        //        let createTableCode = "CREATE TABLE IF NOT EXISTS t_notification ('key' INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'id' INTEGER,'content' TEXT,'time' TEXT,'title' TEXT,'msg_type' INTEGER)"
        
        //3.2 执行创建表的语句
        dbQueue?.inDatabase({ (db) -> Void in
            if db.executeUpdate(createTableCode, withArgumentsInArray: nil)
            {
                print("success")
            } else {
                print("error = \(db.lastErrorMessage())")
            }
        })
    }
}

extension FMDBManager {
    
    func addCamera(camera: SCBCameraDev) {
        
        self.dbQueue?.inDatabase({ [weak camera] (db) in
            
            guard camera != nil else {
                return;
            }
            
            if (self.isEixst(camera!, db: db)) {
                
                if !db.executeUpdate("UPDATE \(FMDBManager.devTable) SET nickname = ?, account = ?, password = ?, channel = ?, connect = ?, sound = ?, stream = ?, pushallow = ?, optMode = ? WHERE uid = ? ", withArgumentsInArray:[camera!.devAlias, camera!.viewAcc, camera!.viewPwd, camera!.devChnl, camera!.devConn, camera!.devSound, camera!.devStream, camera!.pushAllow, camera!.optMode.rawValue, camera!.devId]) {
                    print("UPDATE TABLE FAILURE: \(db.lastErrorMessage())")
                }
                
            } else {
                
                if !db.executeUpdate("INSERT INTO \(FMDBManager.devTable) (uid, nickname, account, password, channel, connect, sound, stream, pushallow, optMode) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", withArgumentsInArray:[camera!.devId, camera!.devAlias, camera!.viewAcc, camera!.viewPwd, camera!.devChnl, camera!.devConn, camera!.devSound, camera!.devStream, camera!.pushAllow, camera!.optMode.rawValue]) {
                    print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
                    return
                }
            }
        })
    }
    
    func addCameras(cameras: NSArray) {
        
        guard cameras.count > 0 else {
            return;
        }
        
        self.dbQueue?.inTransaction({ (db, rollback) in
            
            for item in cameras {
                
                let camera = item as! SCBCameraDev;
                
                if (self.isEixst(camera, db: db)) {
                    
                    if !db.executeUpdate("UPDATE \(FMDBManager.devTable) SET nickname = ?, account = ?, password = ?, channel = ?, connect = ?, sound = ?, stream = ?, pushallow = ?, optMode = ? WHERE uid = ? ", withArgumentsInArray:[camera.devAlias, camera.viewAcc, camera.viewPwd, camera.devChnl, camera.devConn, camera.devSound, camera.devStream, camera.pushAllow, camera.optMode.rawValue, camera.devId]) {
                        print("UPDATE TABLE FAILURE: \(db.lastErrorMessage())")
                        rollback.memory = true;
                    }
                    
                } else {
                    
                    if !db.executeUpdate("INSERT INTO \(FMDBManager.devTable) (uid, nickname, account, password, channel, connect, sound, stream, pushallow, optMode) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", withArgumentsInArray:[camera.devId, camera.devAlias, camera.viewAcc, camera.viewPwd, camera.devChnl, camera.devConn, camera.devSound, camera.devStream, camera.pushAllow, camera.optMode.rawValue]) {
                        print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
                        rollback.memory = true;
                    }
                }
            }
        })
    }
    
    func loadCameras() ->NSMutableArray {
        
        let cameras = NSMutableArray();
        
        self.dbQueue?.inDatabase({ (db) in
            
            if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.devTable)", withArgumentsInArray: nil) {
                
                while(resultSet.next()) {
                    
                    let camera = SCBCameraDev()
                    camera.devId = resultSet.stringForColumn("uid")
                    camera.devAlias = resultSet.stringForColumn("nickname")
                    camera.viewAcc = resultSet.stringForColumn("account")
                    camera.viewPwd = resultSet.stringForColumn("password")
                    camera.devChnl = resultSet.stringForColumn("channel")
                    camera.channel = NSString(string: camera.devChnl).integerValue;
                    camera.devConn = resultSet.stringForColumn("connect")
                    camera.devSound = resultSet.stringForColumn("sound")
                    camera.devStream = resultSet.stringForColumn("stream")
                    camera.pushAllow = resultSet.boolForColumn("pushallow");
                    camera.optMode = SCBCameraOpt(rawValue: Int(resultSet.intForColumn("optMode")))!;
                    cameras.addObject(camera);
                }
                resultSet.close();

            } else {
                print("SELECT identity FAILURE: \(db.lastErrorMessage())")
            }
        })
        
        return cameras;
    }
    
    func isEixst(camera: SCBCameraDev, db: FMDatabase) -> Bool {
        
        var exist = false;
        
        if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.devTable) WHERE uid = ?", withArgumentsInArray: [camera.devId]) {
            
            exist = resultSet.next();
            resultSet.close();
        } else {
            print("SELECT identity FAILURE: \(db.lastErrorMessage())")
        }
        
        return exist;
    }
    
    func isHasCamera() ->Bool {
        return self.loadCameras().count != 0;
    }
    
    func camereDev() -> SCBCameraDev {

//        let uid = "9F22HC358CNUAFT5111A"

//        let uid = "G1KUCHY2UC4889PL111A"
        let uid = "T8UW37J8T55UC1BM111A"
//        let uid = "BFN2TR18DYFUU4UU111A"
        let name = "IPCAM"
        let view_acc = "admin"
        let view_pwd = "123456"
//        let channel = 2;
        
        let camera = SCBCameraDev(name: name, viewAccount: view_acc, viewPassword: view_pwd)
        camera.devId = uid;
        camera.optMode = .SwitchOn;
        camera.channel = 0;
//        camera.connect(uid)
//        camera.start(camera.channel)
//        camera.setupCtrl()
//        camera.startConnect();
        
        return camera
    }
    
    func setupCamere(camera: SCBCameraDev) -> SCBCameraDev {
        
        let uid = camera.devId;
        let name = camera.devAlias;
        let view_acc = camera.viewAcc;
        let view_pwd = camera.viewPwd;
        
        let newCamera = SCBCameraDev(name: name, viewAccount: view_acc, viewPassword: view_pwd)
        
        newCamera.devId = camera.devId;
        newCamera.devAlias = camera.devAlias;
        newCamera.viewAcc = camera.viewAcc;
        newCamera.viewPwd = camera.viewPwd;
        newCamera.devChnl = camera.devChnl;
        newCamera.channel = camera.channel;
        newCamera.devConn = camera.devConn;
        newCamera.devSound = camera.devSound;
        newCamera.devStream = camera.devStream;
        newCamera.pushAllow = camera.pushAllow;
        newCamera.optMode = camera.optMode;
        
//        newCamera.optMode = .SwitchOn;
        newCamera.connect(uid);
        newCamera.start(newCamera.channel);
        newCamera.setupCtrl();
        
        return newCamera
    }
    
    func addLogs(logs: NSMutableArray) {
        
        self.dbQueue?.inTransaction({ (db, rollback) in
            
            for item in logs {
                
                let log = item as! SCBCameraLog;
                
                if (!self.isExistLog(log, db: db)) {
                    
                    if !db.executeUpdate("INSERT INTO \(FMDBManager.monitorLogTable) (devId, type, time,  picture) values (?, ?, ?, ?)", withArgumentsInArray:[log.devId, log.type.rawValue, log.timestampDecimal(), log.picture]) {
                        print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
                        rollback.memory = true;
                    }
                }
            }
        })
        
//        self.dbQueue?.inDatabase({ (db) in
//            
//            db.beginTransaction();
//            
//            for item in logs {
//                
//                let log = item as! SCBCameraLog;
//                
//                if (!self.isExistLog(log, db: db)) {
//                    
//                    if !db.executeUpdate("INSERT INTO \(FMDBManager.monitorLogTable) (devId, type, time,  picture) values (?, ?, ?, ?)", withArgumentsInArray:[log.devId, log.type.rawValue, log.timestampDecimal(), log.picture]) {
//                        print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
//                        return
//                    }
//                }
//            }
//            
//            db.commit();
//        })
    }
    
    func loadLogsWith(startTime: NSDate, endTime: NSDate, camera: SCBCameraDev) -> NSMutableArray {
        
        let logs = NSMutableArray();
        
        self.dbQueue?.inDatabase({ (db) in
            
            if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.monitorLogTable) WHERE time >= ? AND time <= ? AND devId = ? ORDER BY time", withArgumentsInArray: [startTime.timeIntervalSince1970, endTime.timeIntervalSince1970, camera.devId]) {
                
//                let formatter = NSDateFormatter();
//                formatter.dateFormat = "ddHH";
                
                while(resultSet.next()) {
                    
                    let log = SCBCameraLog()
                    log.devId = camera.devId;
                    log.type = SCBCameraLogType(rawValue: resultSet.stringForColumn("type"))!;
                    log.time = NSDate(timeIntervalSince1970: resultSet.doubleForColumn("time"));
                    log.picture = resultSet.stringForColumn("picture");
                    
                    logs.addObject(log);
                    
//                    print("log.time = \(formatter.stringFromDate(log.time))")
                }
                resultSet.close();
                
            } else {
                print("SELECT identity FAILURE: \(db.lastErrorMessage())")
            }
        })
        
        return logs;
    }
    
    func isExistLog(log: SCBCameraLog, db: FMDatabase) -> Bool {
        
        var exist = false;
        
        if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.monitorLogTable) WHERE devId = ? AND time = ? ", withArgumentsInArray: [log.devId, log.timestampDecimal()]) {
            
            exist = resultSet.next();
            resultSet.close();
        } else {
            print("SELECT identity FAILURE: \(db.lastErrorMessage())")
        }
        
        return exist;
    }
}

extension FMDBManager {

    func isDateNotMark() ->Bool {
        
        guard self.isStartOfMonth() != nil else {
            return false;
        }
        
        return self.getNowMark();
    }
    
    func setNowMark() {
        
        if let date = self.isStartOfMonth() {
            
            self.dbQueue?.inDatabase({ (db) in
                
                if (self.isDateEixst(date, db: db)) {
                    
                    if !db.executeUpdate("UPDATE \(FMDBManager.timeMachineTable) SET mark = ? WHERE date = ? ", withArgumentsInArray:[true, date]) {
                        print("UPDATE TABLE FAILURE: \(db.lastErrorMessage())")
                    }
                    
                } else {
                    
                    if !db.executeUpdate("INSERT INTO \(FMDBManager.timeMachineTable) (date, mark) values (?, ?)", withArgumentsInArray:[date, true]) {
                        print("CREATE TABLE FAILURE: \(db.lastErrorMessage())")
                    }
                }
            })
        }
    }
    
    func getNowMark() ->Bool {
        
        var mark = true;
        
        if let date = self.isStartOfMonth() {
            
            self.dbQueue?.inDatabase({ (db) in
                
                if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.timeMachineTable) WHERE date = ?", withArgumentsInArray: [date]) {
                    
                    if (resultSet.next()) {
                        mark = !resultSet.boolForColumn("mark");
                    }
                    resultSet.close();
                }
            })
        }
        
        return mark;
    }
    
    /**
        判断当前是否为一个月的第一天
     
     - returns: 非第一天返回 nil，否则返回该日期
     */
    func isStartOfMonth() ->String? {
        
        var dateString: String?;
        
        let formatter = NSDateFormatter();
        formatter.dateFormat = "yyyy-MM-dd";
        
        let now = formatter.stringFromDate(NSDate())
        
        let regex = "^\\d{4}(-)\\d{2}(-01)$";
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex);
        
        dateString = (predicate.evaluateWithObject(now) ? now : nil);
        
        return dateString;
    }
    
    func isDateEixst(date: String, db: FMDatabase) -> Bool {
        
        var exist = false;
        
        if let resultSet = db.executeQuery("SELECT * FROM \(FMDBManager.timeMachineTable) WHERE date = ?", withArgumentsInArray: [date]) {
            
            exist = resultSet.next();
            resultSet.close();
        } else {
            print("SELECT identity FAILURE: \(db.lastErrorMessage())")
        }
        
        return exist;
    }
}

extension FMDBManager {
    
    func addBaby(baby: SCBBaby) {
        
        self.dbQueue?.inDatabase({ [weak baby] (db) in
            
            guard baby != nil else {
                return;
            }
            
            if (self.isBabyEixst(baby!, db: db)) {
                
                if !db.executeUpdate("UPDATE \(self.uid) SET name = ?, sexual = ?, birthday = ? WHERE tcode = ? ", withArgumentsInArray:[baby!.name, baby!.sexual, baby!.birthdayStr, baby!.tcode]) {
                    print("UPDATE TABLE FAILURE: \(db.lastErrorMessage())")
                }
                
            } else {
                
                if !db.executeUpdate("INSERT INTO \(self.uid) (name, sexual, birthday, tcode) values (?, ?, ?, ?)", withArgumentsInArray:[baby!.name, baby!.sexual, baby!.birthdayStr, baby!.tcode]) {
                    print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
                }
            }
        })
    }
    
    func addBabys(babys: NSArray) {
        
        guard babys.count > 0 else {
            return;
        }
        
        self.dbQueue?.inTransaction({ (db, rollback) in
            
            for item in babys {
                
                let baby = item as! SCBBaby;
                
                if (self.isBabyEixst(baby, db: db)) {
                    
                    if !db.executeUpdate("UPDATE \(self.uid) SET name = ?, sexual = ?, birthday = ? WHERE tcode = ? ", withArgumentsInArray:[baby.name, baby.sexual, baby.birthdayStr, baby.tcode]) {
                        print("UPDATE TABLE FAILURE: \(db.lastErrorMessage())")
                        rollback.memory = true;
                    }
                    
                } else {
                    
                    if !db.executeUpdate("INSERT INTO \(self.uid) (name, sexual, birthday, tcode) values (?, ?, ?, ?)", withArgumentsInArray:[baby.name, baby.sexual, baby.birthdayStr, baby.tcode]) {
                        print("INSERT TABLE FAILURE: \(db.lastErrorMessage())")
                        rollback.memory = true;
                    }
                }
            }
        })
    }
    
    func loadBabys() ->NSArray {
        
        let babys = NSMutableArray();
        
        self.dbQueue?.inDatabase({ (db) in
            
            if let resultSet = db.executeQuery("SELECT * FROM \(self.uid)", withArgumentsInArray: nil) {
                
                let formatter = NSDateFormatter();
                formatter.dateFormat = "yyyy-MM-dd";
                
                while(resultSet.next()) {
                    
                    let baby = SCBBaby()
                    baby.name = resultSet.stringForColumn("name")
                    baby.sexual = resultSet.boolForColumn("sexual")
                    baby.birthday = formatter.dateFromString(resultSet.stringForColumn("birthday"))!;
                    baby.tcode = resultSet.stringForColumn("tcode")
                    babys.addObject(baby);
                }
                resultSet.close();
                
            } else {
                print("SELECT identity FAILURE: \(db.lastErrorMessage())")
            }
        })
        
        return babys;
    }
    
    func isBabyEixst(baby: SCBBaby, db: FMDatabase) -> Bool {
        
        var exist = false;
        
        if let resultSet = db.executeQuery("SELECT * FROM \(self.uid) WHERE tcode = ?", withArgumentsInArray: [baby.tcode]) {
            
            exist = resultSet.next();
            resultSet.close();
        } else {
            print("SELECT identity FAILURE: \(db.lastErrorMessage())")
        }
        
        return exist;
    }
    
    func isHasBaby() ->Bool {
        return self.loadBabys().count != 0;
    }
}

extension FMDBManager {
    
    func saveBeautyPhoto(pictureName: NSTimeInterval) {
        //存储到数据库
        let insertSQL = "INSERT INTO \(FMDBManager.monitorTable) (filePath, camera_id, fileType, time, userName) VALUES (?, ?, ?, ?, ?);"
        FMDBManager.shareInstance().dbQueue?.inDatabase({ (db) in
        
        db.executeUpdate(insertSQL, withArgumentsInArray: [SCBCommom.beautyPhotoDirPath + "/\(pictureName)",FMDBManager.shareInstance().camereDev().devId,"monitor_beauty_photo",pictureName,SCBCameraManager.uid])
        })
    }
}
