require 'smartsheet'
require 'prontoforms'

# Required environment variables
SMARTSHEET_API_TOKEN = ENV['SMARTSHEET_API_TOKEN']
SMARTSHEET_SHEET_ID = ENV['SMARTSHEET_SHEET_ID']
PRONTOFORMS_API_KEY_ID = ENV['PRONTOFORMS_API_KEY_ID']
PRONTOFORMS_API_KEY_SECRET = ENV['PRONTOFORMS_API_KEY_SECRET']
PRONTOFORMS_FORM_ID = ENV['PRONTOFORMS_FORM_ID']

SMARTSHEET_REFERENCE_NUMBER_COLUMN = 1902239039154052
SMARTSHEET_FORM_STATE_COLUMN = 6405838666524548

MAPPING = [
  {
    'id' => 4154038852839300,
    'title' => 'What kind of Claim Management form is it?'
  },
  {
    'id' => 1640357703247748,
    'title' => 'Claim Number'
  },
  {
    'id' => 7269857237460868,
    'title' => 'Claim Date',
  },
  {
    'id' => 8657638480209796,
    'title' => 'Submitted By',
  },
  {
    'id' => 6143957330618244,
    'title' => 'Priority',
  },
  {
    'id' => 3892157516932996,
    'title' => 'Retail/Grocery Name',
  },
  {
    'id' => 8395757144303492,
    'title' => 'Importer/Distributor Name',
  },
  {
    'id' => 1077407749826436,
    'title' => 'Grower/Licensee Name',
  },
  {
    'id' => 5581007377196932,
    'title' => 'Account Number',
  },
  {
    'id' => 3329207563511684,
    'title' => 'Variety',
  },
  {
    'id' => 7832807190882180,
    'title' => 'Fruit Quality Alarm or Incorrect Labeling',
  },
  {
    'id' => 2203307656669060,
    'title' => 'Licensee Design or Market Design',
  },
  {
    'id' => 6706907284039556,
    'title' => 'Root Cause/Investigation',
  },
  {
    'id' => 4455107470354308,
    'title' => 'QA/Technical Comment',
  },
  {
    'id' => 8958707097724804,
    'title' => 'Legal Team Comment',
  },
  {
    'id' => 57060959250308,
    'title' => 'Corrective Action',
  },
  {
    'id' => 4560660586620804,
    'title' => 'Name of Personal Contact',
  },
  {
    'id' => 2308860772935556,
    'title' => 'Email Address of Personal Contact',
  },
  {
    'id' => 6812460400306052,
    'title' => 'Communicated with Contact?',
  },
  {
    'id' => 1182960866092932,
    'title' => 'Has this claim been resolved?',
  },
  {
    'id' => 5686560493463428,
    'title' => 'Claim Status',
  },
  {
    'id' => 494864155600772,
    'title' => 'Country of Fruit Origin',
  },
  {
    'id' => 4998463782971268,
    'title' => 'Destination Market'
  },
  {
    'id' => 2766257610090372,
    'title' => 'Legal Claim Managed By'
  }
]

class Task
  attr_reader :smartsheet, :prontoforms, :form_submissions

  def initialize
    @smartsheet = Smartsheet::Client.new(token: SMARTSHEET_API_TOKEN)
    @prontoforms = ProntoForms::Client.new(PRONTOFORMS_API_KEY_ID, PRONTOFORMS_API_KEY_SECRET)
    # List of all form submission reference numbers
    @form_submissions = {}
  end

  def do
    load_form_submissions

    # data = form_submissions.map { |reference_number, submission|
    #   submission['prontoforms_submission'].pages
    # }
    data = $DATA

    # pp flatten_prontoforms_answers([data.first])

    # Get submissions that need to be updated in Smartsheet:
    #   1. Row exists in Smartsheet
    #   2. Form state has changed in ProntoForms (typically from Dispatched
    #      to Complete)
    to_update = form_submissions.select { |ref_no, submission|
      smartsheet_row = submission['smartsheet_row']
      if smartsheet_row.nil?
        false
      else
        smartsheet_row.fetch(:cells, []).select { |cell|
          cell[:column_id] == SMARTSHEET_FORM_STATE_COLUMN
        }.first.fetch(:value, nil) != submission['prontoforms_submission'].state
      end
    }

    puts "#{to_update.size} submissions to update..."

    to_add = form_submissions.select { |ref_no, submission|
      submission['smartsheet_row'].nil?
    }

    puts "#{to_add.size} submissions to add..."


    to_add.map { |ref_no, submission|
      puts "Adding #{ref_no} to Smartsheet..."
      prontoforms_data = flatten_prontoforms_answers(submission['prontoforms_submission'].pages)
      body = {
        cells: MAPPING.map { |column_def|
          {
            'columnId' => column_def['id'],
            'value' => prontoforms_data[column_def['title']]
          }
        }.concat([
          {
            'columnId' => SMARTSHEET_REFERENCE_NUMBER_COLUMN,
            'value' => ref_no
          },
          {
            'columnId' => SMARTSHEET_FORM_STATE_COLUMN,
            'value' => submission['prontoforms_submission'].state
          }
        ])
      }
      smartsheet.sheets.rows.add(sheet_id: SMARTSHEET_SHEET_ID, body: body)
    }
  end

  def flatten_prontoforms_answers(pages)
    answers = pages.inject({}) { |answers, page|
      page_answers = page['sections'].inject({}) { |answers, section|
        section_answers = {}
        section['answers'].each { |answer|
          section_answers[answer['question']] = answer['values'].first
        }
        answers.merge section_answers
      }
      answers.merge page_answers
    }
  end

  def load_form_submissions
    # First, load up all form submissions from ProntoForms
    submissions = prontoforms.form_submissions query: { fids: PRONTOFORMS_FORM_ID }

    while submissions.items.any?
      items = submissions.items
      items.each { |item|
        @form_submissions[item.reference_number] = {
          'prontoforms_id' => item.id,
          'prontoforms_submission' => item
        }
      }
      submissions = submissions.next
    end

    # Now go through and apply Smartsheet row ID for each submission (if
    # one exists)
    rows = smartsheet.sheets.get(sheet_id: SMARTSHEET_SHEET_ID).fetch(:rows, [])
    rows.each { |row|
      # Get ref number cell value
      ref_no = row.fetch(:cells, []).select { |cell|
        cell[:column_id] == SMARTSHEET_REFERENCE_NUMBER_COLUMN
      }.first.fetch(:value)

      # Check, in case there's an invalid ref number in the sheet
      if !@form_submissions[ref_no].nil?
        @form_submissions[ref_no]['smartsheet_row_id'] = row.fetch(:id)
        @form_submissions[ref_no]['smartsheet_row'] = row
      end
    }
  end
end

Task.new.do
