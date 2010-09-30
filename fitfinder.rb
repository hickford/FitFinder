require 'camping'
require 'active_record'
require 'action_view'
require 'csv'
require 'gchart'
require 'uri' # for URI::escape
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
  
  class Parameters < V 1.1
    def self.up
      change_table Chart.table_name do |t|
        t.float :alpha
        t.float :beta
      end
    end

    def self.down
      change_table Chart.table_name do |t|
        t.remove :alpha
        t.remove :beta
      end    
    end
  end
  
  class Formula < V 1.2
    def self.up
      add_column Chart.table_name, :formula, :string
    end

    def self.down
      remove_column Chart.table_name, :formula
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
      @author = "Anonymous"
      slope = 4*(rand-0.5)
      size = 20
      error = rand
      xs = []
      ys = []
      for i in 1..10
        x = rand  
        y = slope*x + error*Math.sqrt(-2 * Math.log(rand)) * Math.cos(2 * Math::PI * rand)  
        xs << x
        ys << y
      end
      @content = "#{xs.join(",")}\n#{ys.join(",")}"
      render :home
    end
    
    def post
      begin
        csv = CSV::parse(@input.content.strip)
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
        Chart.create(:author=>@input.author,:url=>chart,:alpha=>lr.slope,:beta=>lr.offset)
      rescue
        @error = "could not parse data: should be n by 2 array"
        @content = @input.content.strip
        @author = @input.author
        @charts = []
        render :home
      else
        redirect Index
      ensure
      end
    end
  end
  
  class Style < R '/styles.css'
    def get
     @headers["Content-Type"] = "text/css"
     @body = %{
        div.post {float:none;}
        .author {font-weight: bold; margin: 0.5em;}
        .timestamp {font-style: italic; margin: 0.5em;}
        div:nth-child(even){background-color:white;}
        div:nth-child(odd){background-color:\#eee;}
        textarea {width:100%;}
        .error {color:red;}
        img.formula {vertical-align: top; margin: 1em;}
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
    p do
      "inspired by Rich Martell's "
      a "FitFinder", :href => "http://www.guardian.co.uk/education/mortarboard/2010/apr/28/fitfinder-for-university-library-crushes"
    end
  end

  def home
    h1 "Fit Finder"
    @charts.each do |chart|
      div.post do
        p do
        span.author chart.author
        span.timestamp "%s ago" % ActionView::Helpers::DateHelper.time_ago_in_words(chart.created_at)
        end 
        img.scatter :src => chart.url
        begin:
          tex = "y=%.2fx + %.2f" % [chart.alpha,chart.beta]
          formula = "http://chart.apis.google.com/chart?cht=tx&chl=%s" % URI::escape(tex," +")
          img.formula :src => formula, :alt => tex
        end
      end
    end
    
    h2 "New post"
    form :action => R(Index), :method => :post do
      p "your name:"
      input "", :type => "text", :name => :author, :value=>@author
      p "your data (comma separated values):"
      if @error
        p.error @error
      end
      textarea @content, :name => :content, :rows => 10, :cols => 50
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
