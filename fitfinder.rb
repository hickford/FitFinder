require 'camping'
require 'active_record'
require 'action_view'
require 'csv'
require 'gchart'
include ActionView::Helpers::DateHelper
Camping.goes :FitFinder

dbconfig = YAML.load(File.read('config/database.yml'))
environment = ENV['DATABASE_URL'] ? 'production' : 'development'
FitFinder::Models::Base.establish_connection dbconfig[environment]

module FitFinder::Models
  class Chart < Base
  end
  
  class BasicFields < V 1.0
    def self.up
      create_table Chart.table_name do |t|
      t.string :author
      t.text   :url
      # This gives us created_at and updated_at
      t.timestamps
      end
    end

    def self.down
      drop_table Chart.table_name
    end
  end
end

def FitFinder.create
  FitFinder::Models.create_schema
end

FitFinder.create

module FitFinder::Controllers
  class Index
    def get
      @charts = Chart.all(:order=>"created_at DESC",:limit=>3)  
      
      slope = 4*(rand-0.5)
      offset = rand-0.5
      size = 20
      error = rand
      xs = []
      ys = []
      for i in 1..10
        x = rand  
        y = slope*x+offset + error*Math.sqrt(-2 * Math.log(rand)) * Math.cos(2 * Math::PI * rand)  
        xs << x
        ys << y
      end
      @example = "#{xs.join(",")}\n#{ys.join(",")}"
      render :home
    end
    
    def post
      content = @input.content.strip
      csv = CSV::parse(content)
      if csv.length == 2
        csv = csv.transpose
      end      
      data = csv.collect{|i| i.collect{|j| j.to_f} }

      xs, ys = data.transpose
      size = xs.size
      lr = LinearRegression.new(xs,ys)
      gxs = xs + [xs.min,xs.max]
      gys = ys + [lr.predict(xs.min),lr.predict(xs.max)]
      custom = "chm=o,0000FF,0,-1,0|o,FF0000,0,0:#{size}:,5|D,000000,1,#{size}:,1,-1"
      chart = Gchart.scatter(:data => [gxs,gys],:custom=>custom)
      Chart.create(:author=>@input.author,:created_at=>Time.now,:url=>chart)
      redirect Index
    end
  end
  
  class Style < R '/styles.css'
    def get
     @headers["Content-Type"] = "text/css"
     @body = %{
        .author {font-weight: bold; margin: 0.5em}
        .timestamp {font-style: italic; margin: 0.5em}
        div:nth-child(even){background-color:white}
        div:nth-child(odd){background-color:\#eee}
     }
    end
  end
end

module FitFinder::Views
  def layout
    html do
      head do
        title "Fit Finder"
        link :rel => 'stylesheet',:type => 'text/css',:href => '/styles.css'
      end
      body { self << yield }
    end
  p do
    a "home", :href => R(Index)
  end
  end

  def home
    h1 "Fit Finder"
    @charts.each do |chart|
      div do
        p do
        span.author chart.author
        span.timestamp "%s ago" % ActionView::Helpers::DateHelper.time_ago_in_words(chart.created_at)
        end 
        img :src => chart.url
        br
      end
    end
    
    h2 "New post"
    form :action => R(Index), :method => :post do
      p "your name:"
      input "", :type => "text", :name => :author, :value=>"Anonymous"
      p "your data (comma separated values):"
      textarea @example, :name => :content, :rows => 10, :cols => 50
      br
      input :type => :submit, :value => "post!"    
    end
  end
end

class LinearRegression
  attr_accessor :slope, :offset

  def initialize dx, dy
    @size = dx.size
    sxx = sxy = sx = sy = 0
    dx.zip(dy).each do |x,y|
      sxy += x*y
      sxx += x*x
      sx  += x
      sy  += y
    end
    @slope = ( @size * sxy - sx*sy ) / ( @size * sxx - sx * sx )
    @offset = (sy - @slope*sx) / @size
  end

  def fit
    return axis.map{|data| predict(data) }
  end

  def predict( x )
    y = @slope * x + @offset
  end

  def axis
    (0...@size).to_a
  end
end
