require "open-uri"
require "json"
require 'open3'
require 'pty'
require 'taglib'

#Encoding.default_external = "utf-8"

Bangumi_ID={
  "英会話"=>"PMMJ59J6N2",
  "現代英語"=>"77RQWQX1L6",
  "タイムトライアル"=>"8Z6XJ6J415",
  "ビジネス英語"=>"368315KKP8",
  "エンジョイ・シンプル・イングリッシュ"=>"BR8Z3NX7XM"
}
def download_audio_from_stream(stream_url, output_file)
  # FFmpegコマンドの生成
  ffmpeg_command = "ffmpeg -http_seekable 0 -i #{stream_url} -vn -f mp3 copy #{output_file}"
  puts ffmpeg_command
  # FFmpegを実行して音声をダウンロード 
  PTY.spawn(ffmpeg_command) do |stdout, stdin, pid|
    begin
      # 10秒待ってから "y"+Enter を入力 
      sleep 10
      stdin.puts "y\n"
      # stdoutから出力を読み取り、必要な入力があるかどうかをチェック
        stdout.each do |line|
          puts line
        end
    rescue Errno::EIO
      # EOFエラーが発生したら無視
    end
  end
end
def get_dest_folder(file_name)
    dest_folder ={}
    root_folder = "/Users/inuzuka0601/Library/CloudStorage/Dropbox/☆英語学習/NHK英会話/"
    unless Dir.exist? root_folder
      root_folder = "/Users/inuzuka0601/Dropbox/☆英語学習/NHK英会話/"
      unless Dir.exist? root_folder
        raise StandardError, "Dropbox folder is not found."
      end
    end    
    dest_folder["英会話"] = root_folder+"英会話/2025/"
    dest_folder["ビジネス英語"] = root_folder+"ラジオビジネス英語/2025/"
    dest_folder["現代英語"] = root_folder+"現代英語/放送全体/"
    dest_folder["タイムトライアル"] = root_folder+"タイムトライアル/2025/"
    dest_folder["エンジョイ・シンプル・イングリッシュ"] = root_folder+"エンジョイ・シンプル・イングリッシュ/"
    if file_name.match(/英会話/)
        dest_folder["英会話"]
    elsif file_name.match(/ビジネス/)
        dest_folder["ビジネス英語"]
    elsif file_name.match(/現代英語/)
        dest_folder["現代英語"]
    elsif file_name.match(/タイムトライアル/)
        dest_folder["タイムトライアル"]
    elsif file_name.match(/エンジョイ・シンプル・イングリッシュ/)
        dest_folder["エンジョイ・シンプル・イングリッシュ"]
    end
end

def get_file_name(title,onair_date, custom_number=nil)
  def remove_zenkaku_space(str)
    if str.match(/「.*?」/)
      # カギ括弧の中身を保存しておく
      quoted = $&
      before = $`
      after  = $'
      # カギ括弧の外側だけ全角スペース削除
      before.gsub!(/　/, '')
      after.gsub!(/　/, '')
      # 再構成して返す
      before + quoted + after
    else
      # カギ括弧がないなら普通に全角スペース削除
      str.gsub(/　/, '')
    end
  end
  base_name = title.tr("Ａ-Ｚａ-ｚ０-９！","A-Za-z0-9!").
              gsub(/ラジオ|～|（|）|\(|\)|\s/,"").
              sub(/－/,"-")
  #p "base_name1:"+base_name
  base_name = remove_zenkaku_space(base_name)
  #p "base_name2:"+base_name
  if base_name.match(/現代英語/)
    base_name.sub!(/.*「現代英語」(.*)/){"現代英語"+onair_date+"「"+$1+"」"}
  elsif base_name.match(/エンジョイ・シンプル・イングリッシュ/)
    if custom_number
      # 事前に割り当てられた番号を使用
      base_name.sub!(/エンジョイ・シンプル・イングリッシュ/, custom_number.to_s)
    else
      # 単発ダウンロード用のフォールバック（通常は使用されない）
      base_name.sub!(/エンジョイ・シンプル・イングリッシュ/, "1")
    end
  end
  #p "base_name3:"+base_name
  base_name + ".mp3"
end

def file_exist?(file_path,bangumi_title)
  exist_file_path = nil
  if ["エンジョイ・シンプル・イングリッシュ","現代英語"].include? bangumi_title
    if file_path.match(/今週のスピーキング練習/)
      if (File.exist? file_path) || (File.exist? file_path.encode("UTF-8-MAC","UTF-8"))
        exist_file_path = file_path
      end
    else
      dir_name = File.dirname(file_path)
      element_name = File.basename(file_path).sub(/.*「(.*)」.*/){$1}
      #puts "element_name => " + element_name
      res = Dir.glob(dir_name+"/*.mp3").find{|path| path.encode("UTF-8","UTF-8-MAC").match(/#{element_name}/)}
      exist_file_path = res if res
    end
  else
    if (File.exist? file_path) || (File.exist? file_path.encode("UTF-8-MAC","UTF-8"))
      exist_file_path = file_path
    end
  end
  #puts exist_file_path ? "ダウンロード済み:"+exist_file_path : "新規"
  exist_file_path
end

def get_mp3_by_json(bangumi_title,mode=nil)
  uri="https://www.nhk.or.jp/radio-api/app/v1/web/ondemand/series"
  param={}
  downloaded=[]
  download_error=[]
  not_downloaded=[]
  case bangumi_title
  when "英会話"
    #param["site_id"]="0916"
    param["site_id"]="PMMJ59J6N2"
  when "現代英語"
    #param["site_id"]="7512"
    param["site_id"]="77RQWQX1L6"
  when "タイムトライアル"
    #param["site_id"]="2331"
    param["site_id"]="8Z6XJ6J415"
  when "ビジネス英語"
    #param["site_id"]="6809"
    param["site_id"]="368315KKP8"
  when "エンジョイ・シンプル・イングリッシュ"
    #param["site_id"]="3064"
    param["site_id"]="BR8Z3NX7XM"
  else
     nil
  end
  param["corner_site_id"]="01"

  uri_with_getparam = uri + "?" + param.map{|k,v| k+"="+v}.join("&")

  json = URI.open(uri_with_getparam).read
  #jsonの具体的中身のサンプルが末尾にあるので参照のこと.

  if mode=="json_test"
    puts json
  elsif json=="{}"
    p "json==nil"
    puts bangumi_title
    p uri_with_getparam
  else
    data=JSON.parse(json)
    data["episodes"].each do |h|
        if bangumi_title == "エンジョイ・シンプル・イングリッシュ"
          # program_title の文字数があふれたとき,通常は司会名が入る program_sub_title に括弧書きタイトルを入れていることが判明
          #その場合を考慮して title を設定する。
          title = (h["program_title"]+h["program_sub_title"]).sub(/」.*/,"」")
        else
          title = h["program_title"]
        end
        puts title
        onair_date = h["onair_date"].sub(/(\d+)月(\d+)日.*/){
          Time.now.year.to_s[2,2]+("0"+$1)[-2,2]+("0"+$2)[-2,2]
        }
        file_name = get_file_name(title,onair_date)
        #puts file_name + ", " + onair_date
        #p :file_name
        #p file_name
        #p get_dest_folder(bangumi_title)
        output_file = get_dest_folder(bangumi_title)+file_name
        stream_url = h["stream_url"]
        unless file_exist?(output_file,bangumi_title)
          #puts "go download => " + output_file
          #puts stream_url
          unless mode
            download_audio_from_stream(stream_url, output_file)
            if File.exist?(output_file)
              downloaded << file_name
            else
              download_error << file_name
            end
            #p :downloaded
            #p downloaded
            #sleep 60*3 # ダウンロードが終了しないうちに次のダウンロードを実行するとうまくいかないので3分間待機する。
          end
        else
          not_downloaded << file_name
          #p :not_downloaded
          #p not_downloaded
        end
        #p :next
    end
  end
  [downloaded,download_error,not_downloaded]
end

def select_files_to_download(bangumi_title,mode:nil)
  def episode_data_to_title(episode_data)
    if episode_data["program_title"].include? "エンジョイ・シンプル･イングリッシュ"
      # program_title の文字数があふれたとき,通常は司会名が入る program_sub_title に括弧書きタイトルが入る
      #その場合を考慮して title を設定する。
      title = (episode_data["program_title"]+episode_data["program_sub_title"]).sub(/」.*/,"」")
    else
      title = episode_data["program_title"]
    end
    title
  end
  uri="https://www.nhk.or.jp/radio-api/app/v1/web/ondemand/series"
  need_to_download=[]
  need_not_to_download=[] 
  param={}
  param["site_id"]=Bangumi_ID[bangumi_title]
  param["corner_site_id"]="01"

  uri_with_getparam = uri + "?" + param.map{|k,v| k+"="+v}.join("&")

  json = URI.open(uri_with_getparam).read
  #jsonの具体的中身のサンプルが末尾にあるので参照のこと.
  if mode=="json_test"
    puts json
  elsif json=="{}"
    p "json==nil"
    puts bangumi_title
    p uri_with_getparam
  else
    data=JSON.parse(json)
    
    # エンジョイ・シンプル・イングリッシュの場合、連番を事前に計算
    if bangumi_title == "エンジョイ・シンプル・イングリッシュ"
      # 既存のファイルから最大番号を取得
      folder = get_dest_folder(bangumi_title)
      existing_files = Dir.glob(folder+"*.mp3")
      max_num = 0
      if existing_files.any?
        numbers = existing_files.map do |path|
          match = File.basename(path).match(/^(\d+)/)
          match ? match[1].to_i : 0
        end.compact
        max_num = numbers.max || 0
      end
      
      # 新規ダウンロード用の連番カウンター
      next_number = max_num + 1
    end
    
    data["episodes"].each do |h|
        title = episode_data_to_title(h)
        onair_date = 
          Time.now.year.to_s[-2,2]+
          ('0'+h["onair_date"][/(\d+)月/,1])[-2,2]+
          ('0'+h["onair_date"][/(\d+)日/,1])[-2,2]
        
        # エンジョイ・シンプル・イングリッシュの場合は連番を渡す
        if bangumi_title == "エンジョイ・シンプル・イングリッシュ"
          file_name = get_file_name(title, onair_date, next_number)
          next_number += 1
        else
          file_name = get_file_name(title, onair_date)
        end
        
        output_file = get_dest_folder(bangumi_title)+file_name
        stream_url = h["stream_url"]
        #ダウンロード済みかどうか調べて分類する。
        res = file_exist?(output_file,bangumi_title)
        unless res
          need_to_download << [stream_url, output_file, file_name]
        else
          if res.encode("UTF-8","UTF-8-MAC") != output_file
            need_not_to_download << file_name + "（#{File.basename(res)}）"
          else
            need_not_to_download << file_name
          end
        end
    end
  end
  [need_to_download,need_not_to_download]
end

#以下はmp3ファイルのメタデータのタイトルを変更するためのメソッド
def set_title(file_path,title)
  TagLib::MPEG::File.open(file_path) do |mp3|
    unless mp3.tag.title==title
      mp3.tag.title=title
      mp3.save
      #puts get_title(file_path)
      return title
    end
  end
  nil
end

def get_title(file_path)
  TagLib::MPEG::File.open(file_path) do |mp3|
    return mp3.tag.title
  end
end
######################## ここまでは各種定義　#########################

### ダウンロードしていない番組エピソードを調べる。###
need_to_download=[]
not_need_to_download=[]
["現代英語","英会話","タイムトライアル","ビジネス英語","エンジョイ・シンプル・イングリッシュ"].each do |t|
  need, not_need = select_files_to_download(t)
  need_to_download     = need_to_download     + need
  not_need_to_download = not_need_to_download + not_need
end

### 調査結果を表示する。###
puts "ダウンロード済みのエピソード"
if not_need_to_download.size==0
  "　なし"
else
  not_need_to_download.each do |d|
    puts "　"+d
  end
end
puts
puts "新規ダウンロードするエピソード"
if need_to_download.size==0
  puts "　なし"
else
  need_to_download.each do |d|
    puts "　"+d[2]
  end
end
puts

if need_to_download.size==0
  puts "新規の聞き逃しファルはありませんでした。"  
else
  puts "新規の聞き逃しファルのダウンロードを開始します。"  
  puts 
  ### 新規の聞き逃しファルをWEBから取得 ###
  downloaded = []
  download_error = []
  need_to_download.each.each do |data|
    stream_url, output_file, file_name = data
    download_audio_from_stream(stream_url, output_file)
    if File.exist?(output_file)
      downloaded << file_name
    else
      download_error << file_name
    end
  end

  ### ダウンロードの結果を表示 ###
  puts "新しくダウンロードしたファイル"
  if downloaded.size==0
    puts "　なし"
  else
    downloaded.each do |f|
      puts "　"+f
    end
  end
  puts
  puts "何らかの不具合によってダウンロードできなかったファイル"
  if download_error.size==0
    puts "　なし"
  else
    download_error.each do |f|
      puts "　"+f
    end
  end
end

### 保存されたMP3のメタデータのタイトルをファイル名に合わせる. ###
# 変換するディレクトリのパスを指定
directory_path = "#{__dir__.force_encoding("utf-8")}"
# 指定したディレクトリ内のすべてのファイルに対して処理を実行
new_mp3=[]
Dir.glob(directory_path+"/*") do |path|
  if File.directory? path
    Dir.glob(path+"/*.mp3") do |file_path|
      # ファイル名から拡張子を取り除く
      new_title = File.basename(file_path, ".*")
      # オーディオファイルのタイトルをファイル名に変更
      if set_title(file_path,new_title)
        new_mp3 << new_title
      end
    end
  end
end
File.open("get_mp3.log","a") do |f|
  f.puts Time.now
  if new_mp3.size>0
    f.puts new_mp3.map{|t| "  "+t}
  else
    f.puts "There was nothing to save."
  end
end
puts
if new_mp3.size==0
  puts "メタデータのオーディオタイトルを変更したファイルなし"
else
  puts "メタデータのオーディオタイトルを変更したファイル"
  puts new_mp3.map{|s| "　"+s}
end

__END__
#以下は、127行目の json = URI.open(uri_with_getparam).read の内容のサンプル
json=<<EOS
{"id":43,"title":"エンジョイ・シンプル・イングリッシュ","radio_broadcast":"R2,FM","schedule":"放送：(R2)月曜～金曜　午前6:00～6:05 再放送：(R2)月曜～金曜　午前9:10～9:15、午後0:55～1:00、午後3:25～3:30、午後4:25～4:30、午後11:10～11:15、土曜（5回分）午前6:30～6:55、午前9:05～9:30、日曜（5回分）午後9:30～9:55、(NHK-FM)火曜～土曜（月曜～金曜深夜）午前0:55～1:00","corner_name":"","thumbnail_url":"https://www.nhk.jp/static/assets/images/radioseries/rs/BR8Z3NX7XM/BR8Z3NX7XM-eyecatch_8e6fb9b5034a597a3130829d6701a54f.jpg","series_description":"1日5分、約500語。平易なレベルの英語を多読・多聴し、英語を英語のまま理解する力を身につけます。","series_url":"https://www.nhk.jp/p/rs/BR8Z3NX7XM/","share_text_title":"エンジョイ・シンプル・イングリッシュ","share_text_url":"https://www.nhk.or.jp/radioondemand/share/43_442.html","share_text_description":"#radiru","episodes":[
    
    {"id":4196356,"program_title":"エンジョイ・シンプル・イングリッシュ「乳母桜」","onair_date":"4月18日(金)午前6:00放送","closed_at":"2025年4月25日(金)午前6:05配信終了","stream_url":"https://vod-stream.nhk.jp/radioondemand/r/BR8Z3NX7XM/s/stream_BR8Z3NX7XM_836c1bc1687bf48aafbe95c22883fc14/index.m3u8","aa_contents_id":"[radio]vod;エンジョイ・シンプル・イングリッシュ「乳母桜」;r2,130;2025041873291;2025-04-18T06:00:03+09:00_2025-04-18T06:05:00+09:00","annotation_title":"","annotation_url":"","program_sub_title":"【司会】森崎ウィン"},
    
    {"id":4198060,"program_title":"エンジョイ・シンプル・イングリッシュ","onair_date":"4月21日(月)午前6:00放送","closed_at":"2025年4月28日(月)午前6:05配信終了","stream_url":"https://vod-stream.nhk.jp/radioondemand/r/BR8Z3NX7XM/s/stream_BR8Z3NX7XM_293d999e7eb6e6dd8d13c3d295407950/index.m3u8","aa_contents_id":"[radio]vod;エンジョイ・シンプル・イングリッシュ;r2,130;2025042174104;2025-04-21T06:00:03+09:00_2025-04-21T06:05:00+09:00","annotation_title":"","annotation_url":"","program_sub_title":"「アイルランド　セント・パトリックス・フェスティバル」　【司会】森崎ウィン"},
    
    {"id":4198669,"program_title":"エンジョイ・シンプル・イングリッシュ「ハンカチ落とし」","onair_date":"4月22日(火)午前6:00放送","closed_at":"2025年4月29日(火)午前6:05配信終了","stream_url":"https://vod-stream.nhk.jp/radioondemand/r/BR8Z3NX7XM/s/stream_BR8Z3NX7XM_75e2d4d7c638d273fd4dde5a912834bd/index.m3u8","aa_contents_id":"[radio]vod;エンジョイ・シンプル・イングリッシュ「ハンカチ落とし」;r2,130;2025042274355;2025-04-22T06:00:03+09:00_2025-04-22T06:05:00+09:00","annotation_title":"","annotation_url":"","program_sub_title":"【司会】森崎ウィン"},
    
    {"id":4199731,"program_title":"エンジョイ・シンプル・イングリッシュ「日本がポーランドの孤児を救済」","onair_date":"4月23日(水)午前6:00放送","closed_at":"2025年4月30日(水)午前6:05配信終了","stream_url":"https://vod-stream.nhk.jp/radioondemand/r/BR8Z3NX7XM/s/stream_BR8Z3NX7XM_7fe5a9c6e0409e0c180b88a03bc6bf2f/index.m3u8","aa_contents_id":"[radio]vod;エンジョイ・シンプル・イングリッシュ「日本がポーランドの孤児を救済」;r2,130;2025042374610;2025-04-23T06:00:03+09:00_2025-04-23T06:05:00+09:00","annotation_title":"","annotation_url":"","program_sub_title":"【司会】森崎ウィン"},
    
    {"id":4200354,"program_title":"エンジョイ・シンプル・イングリッシュ「カレンダーの空白が怖い」","onair_date":"4月24日(木)午前6:00放送","closed_at":"2025年5月1日(木)午前6:05配信終了","stream_url":"https://vod-stream.nhk.jp/radioondemand/r/BR8Z3NX7XM/s/stream_BR8Z3NX7XM_13bb518fb567ce3192c5d1bcda9f3e72/index.m3u8","aa_contents_id":"[radio]vod;エンジョイ・シンプル・イングリッシュ「カレンダーの空白が怖い」;r2,130;2025042474860;2025-04-24T06:00:03+09:00_2025-04-24T06:05:00+09:00","annotation_title":"","annotation_url":"","program_sub_title":"【司会】森崎ウィン"}

],"same_tag_series":[
        
        {"id":410,"title":"ニュースで学ぶ「現代英語」","radio_broadcast":"R2,FM","corner_name":"","onair_date":"2025年4月24日(木)放送","thumbnail_url":"https://www.nhk.jp/static/assets/images/radioseries/rs/77RQWQX1L6/77RQWQX1L6-eyecatch_7a11dca399c3214f3dc614618ee09e1a.png","link_url":"","series_site_id":"77RQWQX1L6","corner_site_id":"01"},
        {"id":247,"title":"ラジオビジネス英語","radio_broadcast":"R2,FM","corner_name":"","onair_date":"2025年4月24日(木)放送","thumbnail_url":"https://www.nhk.jp/static/assets/images/radioseries/rs/368315KKP8/368315KKP8-eyecatch_0b04375fa3e487a8d4c831109e391555.jpg","link_url":"","series_site_id":"368315KKP8","corner_site_id":"01"},
        {"id":36,"title":"まいにちロシア語","radio_broadcast":"R2","corner_name":"","onair_date":"2025年4月24日(木)放送","thumbnail_url":"https://www.nhk.jp/static/assets/images/radioseries/rs/YRLK72JZ7Q/YRLK72JZ7Q-eyecatch_5544e5867d532fc0d169d9928e330963.jpg","link_url":"","series_site_id":"YRLK72JZ7Q","corner_site_id":"01"},
        {"id":45,"title":"英会話タイムトライアル","radio_broadcast":"R2,FM","corner_name":"","onair_date":"2025年4月24日(木)放送","thumbnail_url":"https://www.nhk.jp/static/assets/images/radioseries/rs/8Z6XJ6J415/8Z6XJ6J415-eyecatch_1336acff13de1ac37239620019dcdc10.jpg","link_url":"","series_site_id":"8Z6XJ6J415","corner_site_id":"01"}
]}
EOS
