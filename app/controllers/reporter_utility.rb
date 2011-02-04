#
# Copyright (c) Kurt Christensen, The Bit Bakery, 2011.
#
# Licensed under the Artistic License, Version 2.0 (the "License"); you may not use this
# file except in compliance with the License. You may obtain a copy of the License at:
#
# http://www.opensource.org/licenses/artistic-license-2.0.php
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

module ReporterUtility

  # Enumeration class which encapsulates our various Redmine statuses, as well as our interpretations of their meanings
  # TODO - Generalize to support whatever statuses exist, not just our built-in ones...
  class Status


    def initialize id, name
      @id = id
      @name = name
    end

    NEW = Status.new 1, "NEW"
    IN_PROGRESS = Status.new 2, "IN_PROGRESS"
    SIGNED_OFF = Status.new 3, "SIGNED_OFF"
    CLOSED = Status.new 5, "CLOSED"
    TESTED = Status.new 7, "TESTED"
    FIXED = Status.new 9, "FIXED"
    REJECTED = Status.new 10, "REJECTED"

    @@statuses = {1 => NEW, 2 => IN_PROGRESS, 3 => SIGNED_OFF, 5 => CLOSED, 7 => TESTED, 9 => FIXED, 10 => REJECTED}

    def self.get id
      id == nil ? nil : @@statuses[id];
    end

    def is_relevant?
      self == NEW or self == IN_PROGRESS or self == SIGNED_OFF or self == CLOSED or self == TESTED;
    end

    def is_tested?
      self == TESTED or self == CLOSED
    end

    def is_signed_off?
      is_tested? or self == SIGNED_OFF
    end

    def to_s
      @name
    end
    def to_str
      @name
    end
  end


  # Given a set of data, we find a linear best fit using the least squares method.
  #  (http://www.zweigmedia.com/RealWorld/calctopic1/regression.html)
  class Predictor

    # Returns a map of exactly two <x, y> points, thus defining a line
    #def Map<Integer, Double> findLinearFit(ChartLine points, int xMin, int xMax) {
    def find_linear_fit(points, x_min, x_max)
      sum_x, sum_y, sum_xy, sum_x_squared, n = 0

      # Accumulate sums for the data points
      points.each do |x, y|
        if x >= x_min and x <= x_max
          sum_x += x
          sum_y += y
          sum_xy += x * y
          sum_x_squared += x * x
          n += 1
        end
      end

      # Least squares method to find best linear fit
      slope = ((n * sum_xy) - (sum_x * sum_y)) / ((n * sum_x_squared) - (sum_x * sum_x))
      intercept = (sum_y - (slope * sum_x)) / n

      # Define the two endpoints for our best fit line, and return them bundled as a map
      map[x_min] = (x_min * slope) + intercept
      map[x_max] = (x_max * slope) + intercept

      map
    end
  end


  # Contains data and display info for a particular line (i.e., a collection of <x,y> data points) in a Google Line Chart
  class ChartLine < Hash
    def initialize name, color, data_point_display
      @name = name
      @color = color
      @data_point_display = data_point_display
    end
  end

end
