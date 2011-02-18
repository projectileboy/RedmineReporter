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

require 'reporter_utility'

# TODO - The state of things....
# * Chart: Color legend for lines
# * View: Should add parameters to filter on particular parameters
# * Controller: Export data to CSV (see issues_helper.rb for sample code)
# * Controller: Scope data based on current project (inluding child projects)
# * Controller: Change hard-coded constants to user-configurable values (e.g., tracker_id)
#
class ReporterController < ApplicationController
  unloadable

  # before_filter :find_project, :authorize, :only => :burnup

  # TODO - Simply take the first date for which we have data, or else a user-defined value
  DATE_ZERO = Date.strptime "2009-08-04" # The date on which this project started
  YEAR_ZERO = DATE_ZERO.year
  DAY_ZERO = DATE_ZERO.yday # day of year

  def initialize
    @tested = {}
    @signed = {}
    @planned = {}
  end

  def burnup
    # TODO - Filter which projects get pulled by default - get rid of the hard-coded IDs in the SQL
    # TODO - Additionally, we need a selection box that lets you pick and choose child projects to ignore
#    @project = Project.find(params[:id])
#    @project.children.each do |child|
#      puts child
#    end

    included_projects = "(1,3,4,5,6,7,8,9,10,11,12,13,14,15,17,19,21,22,23)"

    # Fetch historical burnup data directly from the database
    results = ActiveRecord::Base.connection.execute <<-SQL

    SELECT issues.id,
        issues.estimated_hours,
        issues.status_id,
        issues.created_on,
        journals.created_on as modified_on,
        journal_details.prop_key,
        journal_details.old_value
    FROM journals, journal_details, issues
        LEFT OUTER JOIN custom_values
            ON (issues.id = custom_values.customized_id
                AND custom_values.custom_field_id = 6
                AND custom_values.value != 1)
    WHERE issues.tracker_id != 5
        AND issues.project_id in #{included_projects}
        AND issues.id = journals.journalized_id
        AND journals.id = journal_details.journal_id
        AND journal_details.prop_key in (' status_id ', ' estimated_hours ')

        UNION ALL

    SELECT issues.id,
        issues.estimated_hours,
        issues.status_id,
        issues.created_on,
        NULL, NULL, NULL
    FROM issues
        LEFT OUTER JOIN custom_values
            ON (issues.id = custom_values.customized_id
                AND custom_values.custom_field_id = 6
                AND custom_values.value != 1)
    WHERE issues.tracker_id != 5
        AND issues.project_id in #{included_projects}

    ORDER BY issues.id, modified_on DESC
    SQL


    #  We walk backwards through the history, issue by issue, to gather the historical burnup data.
    #   Note that we assume the data is ordered by issues.id, modified_on desc - otherwise this all breaks!
    status = nil
    estimated_days = nil

    results.each do |row|

      if status.nil? and estimated_days.nil?
        # We're at the first (that is, most recent) entry for this issue
        estimated_days = row[1]
        status = ReporterUtility::Status.get row[2]
      end

      modified_date = get_date row[4]
      if modified_date.nil?
        # We're at the "created_date" entry for this issue...
        created_date = get_date row[3]
        record_estimate_change(status, created_date, estimated_days)

        # Clear out the cached values - next row will be a new issue
        status = nil
        estimated_days = nil

      else
        # We're at a history entry for this particular issue - record the diff,
        #  and then update the status or estimated_days to the next older value
        prop = row[5]
        if prop == "status_id"
          record_status_change status, modified_date, estimated_days
          status = Status.get row[6] # Old status
        elsif prop == "estimated_hours" # Note that we actually measure estimates in ideal days
          old_estimate = row[6]
          diff = estimated_days - (old_estimate == null ? 0 : old_estimate)
          record_estimate_change status, modified_date, diff
          estimated_days = old_estimate
        end
      end
    end

    @tested = build_chart_line(@tested)
    @signed = build_chart_line(@signed)
    @planned = build_chart_line(@planned)
  end


  # TODO - Add dotted line for target end date
  def get_completion_week(total_work, prediction_data)
#    entries = prediction_data.entrySet().iterator(); # TODO - FIX ME!!!
#
#    # Map.Entry<Integer, Double>
#    xy1 = entries.next()
#    xy2 = entries.next()
#
#    slope = (xy2.getValue() - xy1.getValue()) / (xy2.getKey() - xy1.getKey())
#    total_work / slope
  end

  # Add a chart line for a given data set, grouping the data (which is by individual day) by week
  def build_chart_line(data)
    accum = 0
    week = 0

    # TODO - In Ruby 1.8, hashes do NOT maintain insertion sort order!! Grr... so we have to do a stupid data structure dance...
    arr = []
    data.each { |date, estimate_diff| arr << [date, estimate_diff] }
    arr = arr.sort_by {|x| x.first }

    line = []
    arr.each do |point|
      # We display data by the week, only showing completed weeks
      day = get_normalized_day point[0] # date
      puts day
      if day >= (7 * (week + 1))
        line.push [week, accum]
        week = day / 7
      end
      accum += point[1] # estimate
    end

    line
  end

  # TODO - Add a chart line which shows a predicted continuation over time (which we do with a simple line)
  def build_predictive_chart_line(name, color, index, data)
    line = ChartLine.new name, color, "o," + color + "," + index + ",-1,4.5"
    data.each do |key, value|
      line[key] = value
    end
    line
  end

  # For an historical entry for an issue in Redmine, we normalize the date to be the number of days
  # since "day zero" (2009/8/4) for the NMS project.
  def get_normalized_day dd
    date = Date.strptime(dd)
    if date.year == YEAR_ZERO
      return date.yday - DAY_ZERO
    elsif date.year > YEAR_ZERO
      # TODO - This is broken...
      return (((date.year - 1) - YEAR_ZERO) * ((Date.leap? date.year) ? 366 : 365)) + (365 - DAY_ZERO) + date.yday
    end
    raise Exception.new "Something is wrong with the year for this entry"
  end


  # If the status for a particular issue changed at some point, we need to add/subtract the estimated days
  # for that issue to the appropriate lines in the burnup chart.
  def record_status_change(status, modified_date, estimated_days)
    if status.is_tested?
      add_estimated_days_on_date @tested, modified_date, estimated_days
    elsif status.is_signed_off?
      add_estimated_days_on_date @signed, modified_date, estimated_days
    elsif status.is_relevant?
      add_estimated_days_on_date @planned, modified_date, estimated_days
    end
  end

  # If the estimated days for a particular issue changed at some point, we need to account for how this affected
  # the total count for any given status line in the burnup chart.
  def record_estimate_change(status, modified_date, estimate_diff)
    if status.is_relevant?
      add_estimated_days_on_date(@planned, modified_date, estimate_diff)
      if status.is_signed_off?
        add_estimated_days_on_date(@signed, modified_date, estimate_diff)
        if status.is_tested?
          add_estimated_days_on_date(@tested, modified_date, estimate_diff)
        end
      end
    end
  end

  # Within the given ledger (there's a different one for each issue status), add/subtract the estimated_days
  # that were added/subtracted on the modified_date. This accounts for any historical changes in estimated days
  # which took place for a given issue.
  def add_estimated_days_on_date(ledger, modified_date, estimated_days)
    if estimated_days.nil? or estimated_days == ""
      estimated_days = 0
    end

    if ledger[modified_date].nil?
      ledger[modified_date] = estimated_days
    else
      ledger[modified_date] += estimated_days
    end
  end

# Clips any time information from a SQLite datetime string
  def get_date(sqlite_date)
    sqlite_date.nil? ? nil : sqlite_date[0..9]
  end
end
