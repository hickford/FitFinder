require './fitfinder.rb'

dbconfig = YAML.load(File.read('config/database.yml'))
environment = ENV['DATABASE_URL'] ? 'production' : 'development'
FitFinder::Models::Base.establish_connection dbconfig[environment]

FitFinder.create

run FitFinder
