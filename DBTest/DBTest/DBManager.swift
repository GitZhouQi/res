//
//  DBManager.swift
//  caizhu
//
//  Created by zhouqi on 2017/6/1.
//  Copyright © 2017年 gfcj. All rights reserved.
//

import UIKit

class DBManager: NSObject {
    
    let field_MovieID = "movieID"
    let field_MovieTitle = "title"
    let field_MovieCategory = "category"
    let field_MovieYear = "year"
    let field_MovieURL = "movieURL"
    let field_MovieCoverURL = "coverURL"
    let field_MovieWatched = "watched"
    let field_MovieLikes = "likes"
    
    //创建单例对象
    static let shared: DBManager = DBManager()
    
    //数据库文件名，这并不是一定要作为属性，但是方便重用。
    let databaseFileName = "kofuf.sqlite"
    //数据库文件的路径
    var pathToDatabase: String!
    //FMDatabase对象用于访问和操作实际的数据库
    var database: FMDatabase!
    
    override init() {
        super.init()
        //创建数据库文件路径
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        pathToDatabase = documentDirectory.appending("/\(databaseFileName)")
        _ = createDatabase()
    }
    
    //自定义创建数据库方法，返回布尔值，如果为true，那么数据库创建成功，否则失败
    func createDatabase() -> Bool{
        var created = false
        //如果数据库文件不存在那么就创建，存在就不创建
        if !FileManager.default.fileExists(atPath: pathToDatabase) {
            database = FMDatabase(path: pathToDatabase)
            if database != nil{
                //数据库是否被打开
                if database.open() {
                    //为数据库创建表，表中的相关属性都是依据MovieInfo结构体模型
                    let createMoviesTableQuery = "create table movies (\(field_MovieID) integer primary key autoincrement not null, \(field_MovieTitle) text not null, \(field_MovieCategory) text not null, \(field_MovieYear) integer not null, \(field_MovieURL) text, \(field_MovieCoverURL) text not null, \(field_MovieWatched) bool not null default 0, \(field_MovieLikes) integer not null)"
                    
                    do{
                        //执行查询，将为数据库创建新的表，这里需要使用try-catch来捕获异常
                        try database.executeUpdate(createMoviesTableQuery, values: nil)
                        //表创建成功，设置created为true
                        created = true
                    }catch{
                        print("Could not create table.")
                        print(error.localizedDescription)
                    }
                    
                    //关闭数据库
                    database.close()
                }else{
                    print("Could not open the database.")
                }
            }
        }
        return created
    }
    
    //打开数据库
    func openDatabase() -> Bool{
        //确认database对象是否被初始化，如果为nil，那么判断路径是否存在并创建
        if database == nil{
            if FileManager.default.fileExists(atPath: pathToDatabase){
                database = FMDatabase(path: pathToDatabase)
            }
        }
        //如果database对象存在，打开数据库，返回真，表示打开成功，否则数据库文件不存在或者发生了其它错误
        if database != nil{
            if database.open(){
                return true
            }
        }
        return false
    }
    
    func insertMovieData(){
        if openDatabase(){
            if let pathToMoviesFile = Bundle.main.path(forResource: "movies", ofType: "tsv"){
                do{
                    //因为使用contentsOfFile初始化String可能出现异常，所以使用do-catch捕获异常
                    let moviesFileContents = try String(contentsOfFile: pathToMoviesFile)
                    //基于"\r\n"将字符串变成数组
                    let moviesData = moviesFileContents.components(separatedBy: "\r\n")
                    
                    var query = ""
                    for movie in moviesData{
                        let movieParts = movie.components(separatedBy: "\t")
                        if movieParts.count == 5{
                            let movieTitle = movieParts[0]
                            let movieCategory = movieParts[1]
                            let movieYear = movieParts[2]
                            let movieURL = movieParts[3]
                            let movieCoverURL = movieParts[4]
                            
                            //创建查寻语句，注意，每一个查寻语句最后使用分号(;)结束，因为我们想同时执行多条查寻语句，SQLite将基于分号来区别对应的查寻语句，而且对于values的每一个值，如果是字符串类型引用需要使用单引号括起来。最后两个值使用了默认值0
                            query += "insert into movies (\(field_MovieID), \(field_MovieTitle), \(field_MovieCategory), \(field_MovieYear), \(field_MovieURL), \(field_MovieCoverURL), \(field_MovieWatched), \(field_MovieLikes)) values (null, '\(movieTitle)', '\(movieCategory)', \(movieYear), '\(movieURL)', '\(movieCoverURL)', 0, 0);"
                        }
                    }
                    
                    //对于FMDB，同时执行多条查寻语句是非常容易的
                    if !database.executeStatements(query){
                        //打印插入操作所遭遇的问题
                        print("Failed to insert initial data into the database.")
                        print(database.lastError(), database.lastErrorMessage())
                    }
                }catch{
                    print(error.localizedDescription)
                }
            }
            //记得最后关闭数据库
            database.close()
        }
    }
    
    //Loading Data  记得每一次操作都需要打开和关闭数据库
    func loadMovies() -> [MovieInfo]!{
        var movies: [MovieInfo]!
        
        if openDatabase(){
            //创建SQL查寻语句，加载数据，这里是基于field_MovieYear值的升序排列
            let query = "select * from movies order by \(field_MovieYear) asc"
            do{
                print(database)
                //执行SQL语句,该方法需要两个参数，第一个是查寻的语句，第二个是数组，数组中可以包含想查寻的值，并且返回FMResultSet对象，该对象包含了获取的值
                let results = try database.executeQuery(query, values: nil)
                //遍历查寻结果，创建MovieInfo实例对象，并添加到数组中
                while results.next() {
                    let movie = MovieInfo(movieID: Int(results.int(forColumn: field_MovieID)),
                                          title: results.string(forColumn: field_MovieTitle),
                                          category: results.string(forColumn: field_MovieCategory),
                                          year: Int(results.int(forColumn: field_MovieYear)),
                                          movieURL: results.string(forColumn: field_MovieURL),
                                          coverURL: results.string(forColumn: field_MovieCoverURL),
                                          watched:  results.bool(forColumn: field_MovieWatched),
                                          likes:  Int(results.int(forColumn: field_MovieLikes))
                    )
                    if movies == nil{
                        movies = [MovieInfo]()
                    }
                    
                    movies.append(movie)
                }
            }catch{
                print(error.localizedDescription)
            }
            database.close()
        }
        return movies
    }
    
    func loadMovie(withID ID:Int, completionHandler: (_ movieInfo: MovieInfo?) -> Void){
        var movieInfo: MovieInfo!
        
        if openDatabase(){
            //建立查寻语句
            let query = "select * from movies where \(field_MovieID)=?"
            
            do{
                //执行查寻
                let results = try database.executeQuery(query, values: [ID])
                //创建对象的数据模型对象
                if results.next() {
                    movieInfo = MovieInfo(movieID: Int(results.int(forColumn: field_MovieID)),
                                          title: results.string(forColumn: field_MovieTitle),
                                          category: results.string(forColumn: field_MovieCategory),
                                          year: Int(results.int(forColumn: field_MovieYear)),
                                          movieURL: results.string(forColumn: field_MovieURL),
                                          coverURL: results.string(forColumn: field_MovieCoverURL),
                                          watched: results.bool(forColumn: field_MovieWatched),
                                          likes: Int(results.int(forColumn: field_MovieLikes))
                    )
                    
                }
                else {
                    print(database.lastError())
                }
                
            }catch{
                print(error.localizedDescription)
            }
            //关闭数据库
            database.close()
        }
        //回调查寻的数据
        completionHandler(movieInfo)
    }
    
    //使用具体的电影数据更新数据库
    func updateMovie(withID ID: Int, watched: Bool, likes: Int){
        if openDatabase() {
            //创建更新语句 以电影的ID为准，更新数据
            let query = "update movies set \(field_MovieWatched)=?, \(field_MovieLikes)=? where \(field_MovieID)=?"
            
            do {
                //执行SQL语句
                try database.executeUpdate(query, values: [watched, likes, ID])
            }
            catch {
                print(error.localizedDescription)
            }
            database.close()
        }  
    }
    
    func deleteMovie(withID ID: Int) -> Bool {
        var deleted = false
        
        if openDatabase() {
            //更具选中电影的ID，创建查寻语句
            let query = "delete from movies where \(field_MovieID)=?"
            
            do {
                //执行删除
                try database.executeUpdate(query, values: [ID])
                deleted = true
            }
            catch {
                print(error.localizedDescription)
            }
            //关闭数据库
            database.close()
        }
        
        return deleted
    }
}
