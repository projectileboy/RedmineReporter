# Much of this was originally written in Java, and probably violates the Ruby way.
# Readers are encouraged to improve it!

require 'reporter_utility'


# TODO - The state of things....
# Chart: Font sizes, labels, colors, margin for labels and title
# Controller: Hashes need to be sorted; or else use a different data structure (pairs in an array)
# Controller + Chart: Pass data to chart to have lines drawn
# View: Should add parameters to filter on particular parameters
# Controller: Need to figure out if its possible to parameterize a block string in Ruby - I'd like to do this to my big SQL string
#


class ReporterController < ApplicationController
  unloadable

  # before_filter :find_project, :authorize, :only => :burnup

  # TODO - We could perhaps generalize this to simply take the first date for which we have data, or else a user-defined value
  DATE_ZERO = Date.strptime "2009-08-04" # The date on which this project started
  YEAR_ZERO = DATE_ZERO.year
  DAY_ZERO = DATE_ZERO.yday # day of year


  # TODO - In Ruby 1.8, hashes do NOT maintain insertion sort order!!

  def initialize
    @tested = {}
    @signed = {}
    @planned = {}
  end

  def burnup
    # flash[:notice] = 'Just checking...'

    # Historical data

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
        AND issues.project_id in (1,3,4,5,6,7,8,9,10,11,12,13,14,15,17,19,21,22,23)
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
        AND issues.project_id in (1,3,4,5,6,7,8,9,10,11,12,13,14,15,17,19,21,22,23)

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

    # @tested.
  end


  def find_project
    # @project variable must be set before calling the authorize filter
#    @project = Project.find(params[:project_id]) TODO - This is blowing up!
  end

  #                           Double  Map<Integer, Double>
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
  #                  String, String, int, Map<String, Double>
  def build_chart_line(name, color, index, data)
    line = ReporterUtility::ChartLine.new name, color, "o," + color + "," + index + ",-1,4.0"
    accum, week = 0
    data.each do |date, estimate|

      # We display data by the week, only showing completed weeks
      day = get_normalized_day date
      if day >= (7 * (week + 1))
        line[week] = accum
        week = day / 7
      end
      accum += estimate
    end
    line
  end

  # Add a chart line which shows a predicted continuation over time (which we do with a simple line)
  #                                  String, String, int, Map<Integer, Double>
  def build_predictive_chart_line(name, color, index, data)
    line = ChartLine.new name, color, "o," + color + "," + index + ",-1,4.5"
    data.each do |key, value|
      line[key] = value
    end
    line
  end

  # For an historical entry for an issue in Redmine, we normalize the date to be the number of days
  # since "day zero" (2009/8/4) for the NMS project.
  #             Map.Entry<String, Double> e
  def get_normalized_day dd
    date = Date.strptime(dd)
    if date.year == 0
      return date.yday - DAY_ZERO
    elsif date.year >= 1
      return ((date.year - 1) * ((Date.leap? date.year) ? 366 : 365)) + (365 - DAY_ZERO) + date.yday
    end
    raise Exception.new "Something is wrong with the year for this entry"
  end


  # If the status for a particular issue changed at some point, we need to add/subtract the estimated days
  # for that issue to the appropriate lines in the burnup chart.
  #                          Status,    String,     Double
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
  #                           Status,    String,     Double
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
  #                      Map<String, Double>, String, Double
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
