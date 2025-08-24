Encoding.default_external = "utf-8"

path="/Users/inuzuka0601/Dropbox/☆英語学習/NHK英会話/エンジョイ・シンプル・イングリッシュ"
month_num = {"4月号"=>(124..143),"5月号"=>(144..163),"６月号"=>(164..183),"7月号"=>(184..203),"8月号"=>(204..223)}
yobi_title = {}
yobi_title["月曜日"]="発見!世界の祭り"
yobi_title["火曜日"]="オリジナル・ショート・ストーリー"
yobi_title["水曜日"]="アメージング・ストーリー"
yobi_title["木曜日"]="哲学者からの教え"
yobi_title["金曜日"]="小泉八雲が残した日本の民話"

#*** {連番=>[タイトル,ファイルパス]}のハッシュを作成 ***
files_hash={}
Dir.glob(path+"/*.mp3").each do |mp3|
  title = mp3[/\d+「.*?」/]
  num = File.basename(mp3)[/^\d+/]
  if num and num.to_i >= 124  #2025年度の放送を対象にする。 
    files_hash[num.to_i]=[title,mp3]
  end
end
p files_hash.keys

def yobi2num(yobi)
  res=[]
  if yobi=="月曜日"
    (24..50).each do |i|
        res << i*5+4
    end
  elsif yobi=="火曜日"
    (25..50).each do |i|
        res << i*5
    end
  elsif yobi=="水曜日"
    (25..50).each do |i|
        res << i*5+1
    end
  elsif yobi=="木曜日"
    (25..50).each do |i|
        res << i*5+2
    end
  elsif yobi=="金曜日"
    (25..50).each do |i|
        res << i*5+3
    end
  end
  res
end

#*** 曜日別に分別 ***
str_array=[]
month_num.keys.each do |m|
  str_array << "!!"+m
  yobi_title.keys.each do |yobi|
    str_array << "!!!#{yobi}　#{yobi_title[yobi]}"
    (files_hash.keys & yobi2num(yobi)).each do |num|
      str_array << "*[[#{files_hash[num][0]}|#{files_hash[num][1]}]]" if month_num[m].include? num
    end
  end
end
puts str_array.join("\n")