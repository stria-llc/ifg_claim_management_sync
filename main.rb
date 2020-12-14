require 'smartsheet'
require 'prontoforms'

require 'dotenv'
Dotenv.load

# Required environment variables
SMARTSHEET_API_TOKEN = ENV['SMARTSHEET_API_TOKEN']
SMARTSHEET_SHEET_ID = ENV['SMARTSHEET_SHEET_ID']
PRONTOFORMS_API_KEY_ID = ENV['PRONTOFORMS_API_KEY_ID']
PRONTOFORMS_API_KEY_SECRET = ENV['PRONTOFORMS_API_KEY_SECRET']
PRONTOFORMS_FORM_ID = ENV['PRONTOFORMS_FORM_ID']

SMARTSHEET_REFERENCE_NUMBER_COLUMN = 1902239039154052
SMARTSHEET_FORM_STATE_COLUMN = 6405838666524548

SMARTSHEET_LINK_TO_SUBMISSION_COLUMN = 1730565975107460

# Pairing of question unique IDs (label key) and Smartsheet column IDs
# (id key)
MAPPING = [
  {
    'id' => 4154038852839300,
    'label' => 'KindClaimManagement'
  },
  {
    'id' => 1640357703247748,
    'label' => 'ClaimNumber'
  },
  {
    'id' => 7269857237460868,
    'label' => 'ClaimDate',
  },
  {
    'id' => 6143957330618244,
    'label' => 'Priority',
  },
  {
    'id' => 3892157516932996,
    'label' => 'RetailGroceryName',
  },
  {
    'id' => 8395757144303492,
    'label' => 'ImporterDistributor',
  },
  {
    'id' => 1077407749826436,
    'label' => 'GrowerLicenseeName',
  },
  {
    'id' => 5581007377196932,
    'label' => 'AccountNumber',
  },
  {
    'id' => 3329207563511684,
    'label' => 'Variety',
  },
  {
    'id' => 7832807190882180,
    'label' => 'FQorIL',
  },
  {
    'id' => 2203307656669060,
    'label' => 'LDorMD',
  },
  {
    'id' => 6706907284039556,
    'label' => 'RootCauseInvestigati',
  },
  {
    'id' => 4455107470354308,
    'label' => 'QATechnicalComment',
  },
  {
    'id' => 8958707097724804,
    'label' => 'LegalTeamComment',
  },
  {
    'id' => 57060959250308,
    'label' => 'CorrectiveAction',
  },
  {
    'id' => 4560660586620804,
    'label' => 'NamePersonalContact',
  },
  {
    'id' => 2308860772935556,
    'label' => 'EmailAddressPC',
  },
  {
    'id' => 6812460400306052,
    'label' => 'CommunicatedContact',
  },
  {
    'id' => 1182960866092932,
    'label' => 'ClaimResolved',
  },
  {
    'id' => 5686560493463428,
    'label' => 'ClaimStatus',
  },
  {
    'id' => 494864155600772,
    'label' => 'CountryFruitOrigin',
  },
  {
    'id' => 4998463782971268,
    'label' => 'DestinationMarket'
  },
  {
    'id' => 2766257610090372,
    'label' => 'ManageLegalClaim'
  },
  {
    'id' => 5969794745821060,
    'label' => 'ManageQCClaim'
  },
  {
    'id' => 3717994932135812,
    'label' => 'ManageTechClaim'
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

    to_update.map { |ref_no, submission|
      puts "Updating #{ref_no} in Smartsheet..."
      smartsheet_row = submission['smartsheet_row']
      body = smartsheet_body(ref_no, submission, smartsheet_row[:id])
      smartsheet.sheets.rows.update(sheet_id: SMARTSHEET_SHEET_ID, body: body)
      begin
        if submission['prontoforms_submission'].state == 'Complete'
          filename = "ProntoForms PDF #{submission['prontoforms_submission'].reference_number}.pdf"
          attachment = smartsheet.sheets.rows.attachments.list(
            sheet_id: SMARTSHEET_SHEET_ID,
            row_id: smartsheet_row[:id]
          ).fetch(:data).find do |att|
            att[:name] == filename
          end
          # Only attach if not found
          if attachment.nil? # 23137962003
            puts submission['prontoforms_submission'].id
            documents = submission['prontoforms_submission'].documents(populate: true)
            puts documents.size
            document = documents.find do |doc|
              puts doc.type
              doc.type == 'Pdf'
            end
            puts document.id
            pdf = submission['prontoforms_submission'].download_document(document)
            smartsheet.sheets.rows.attachments.attach_file(
              sheet_id: SMARTSHEET_SHEET_ID,
              row_id: smartsheet_row[:id],
              file: pdf,
              filename: filename,
              file_length: pdf.size
            )
          end
        end
      rescue => e
        puts e.message
      end
    }

    to_add.map { |ref_no, submission|
      puts "Adding #{ref_no} to Smartsheet..."
      body = smartsheet_body(ref_no, submission)
      smartsheet.sheets.rows.add(sheet_id: SMARTSHEET_SHEET_ID, body: body)
      begin
        document = submission['prontoforms_submission'].documents(populate: true).find do |doc|
          doc.type == 'Pdf'
        end
        pdf = submission['prontoforms_submission'].download_document(document)
        smartsheet.sheets.rows.attachments.attach_file(
          sheet_id: SMARTSHEET_SHEET_ID,
          row_id: smartsheet_row[:id],
          file: pdf,
          filename: "ProntoForms PDF #{submission['prontoforms_submission'].reference_number}.pdf",
          file_length: pdf.size
        )
      rescue => e
        puts e.message
      end
    }
  end

  def smartsheet_body(ref_no, submission, row_id = nil)
    prontoforms_data = flatten_prontoforms_answers(submission['prontoforms_submission'].pages)
    dispatcher = submission['prontoforms_submission'].dispatcher
    submitted_by = dispatcher.nil? ? '' : dispatcher.display_name
    body = {
      cells: MAPPING.map { |column_def|
        {
          'columnId' => column_def['id'],
          'value' => prontoforms_data[column_def['label']]
        }
      }.concat([
        {
          'columnId' => SMARTSHEET_LINK_TO_SUBMISSION_COLUMN,
          'value' => "https://live.prontoforms.com/data/v2/#{submission['prontoforms_submission'].id}"
        },
        {
          'columnId' => SMARTSHEET_REFERENCE_NUMBER_COLUMN,
          'value' => ref_no
        },
        {
          'columnId' => 8657638480209796,
          'value' => submitted_by
        },
        {
          'columnId' => SMARTSHEET_FORM_STATE_COLUMN,
          'value' => submission['prontoforms_submission'].state
        }
      ])
    }
    if !row_id.nil?
      body[:id] = row_id
    end
    return body
  end

  def flatten_prontoforms_answers(pages)
    answers = pages.inject({}) { |answers, page|
      page_answers = page['sections'].inject({}) { |answers, section|
        section_answers = {}
        section['answers'].each { |answer|
          section_answers[answer['label']] = answer['values'].first
        }
        answers.merge section_answers
      }
      answers.merge page_answers
    }
  end

  def load_form_submissions
    # First, load up all form submissions from ProntoForms
    submissions = prontoforms.form_submissions query: { fids: PRONTOFORMS_FORM_ID }

    while !submissions.nil?
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
