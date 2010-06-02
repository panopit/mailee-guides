require 'rubygems'
require 'sinatra'
require 'haml'

$KCODE = 'u' if RUBY_VERSION < '1.9'
before do
  content_type :html, 'charset' => 'utf-8'
end

set :public, File.dirname(__FILE__) + '/output'


#get '/' do
#  Dir.chdir('source'){ @files = Dir.glob('*.textile') }
#  haml :index
#end

get '/' do
  Dir.chdir('source'){ @files = Dir.glob('*.textile') }
  @file_name = params[:file]
  haml :index
end

get '/:file' do
  Dir.chdir('source'){ @files = Dir.glob('*.textile') }
  @file_name = params[:file]
  @file = File.read("source/#{@file_name}")
  @first_part = @file_name.split(/\./).shift

  haml :edit
end

post '/:file' do
  #Dir.chdir('source'){ @files = Dir.glob('*.textile') }
  @file_name = params[:file]
  @file = File.open("source/#{@file_name}",'w')
  @file.write params[:file_content]

  @first_part = @file_name.split(/\./).shift

  `ruby spree_guides.rb #{@first_part}`
  redirect "#{@first_part}.html"

end
#get '/preview/:file' do
#  File.read("output/#{params[:file]}")
#end

