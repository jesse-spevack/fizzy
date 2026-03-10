require "test_helper"

class Account::DataTransfer::ActiveStorage::BlobRecordSetTest < ActiveSupport::TestCase
  test "check rejects blob key starting with dot-dot" do
    assert_path_traversal_rejected("../../../etc/passwd")
  end

  test "check rejects blob key starting with forward slash" do
    assert_path_traversal_rejected("/etc/passwd")
  end

  test "check rejects blob key starting with dot-slash" do
    assert_path_traversal_rejected("./some/path")
  end

  test "check rejects blob key starting with backslash" do
    assert_path_traversal_rejected("\\windows\\system32")
  end

  test "check rejects blob key starting with dot" do
    assert_path_traversal_rejected(".hidden")
  end

  test "check accepts valid blob key" do
    blob_data = valid_blob_data

    zip = build_zip(blob_data)
    record_set = Account::DataTransfer::ActiveStorage::BlobRecordSet.new(importing_account)

    assert_nothing_raised do
      record_set.check(from: zip)
    end
  end

  test "check rejects blob with duplicate key" do
    existing_blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "existing.txt", content_type: "text/plain", byte_size: 1, checksum: "x=="
    )
    blob_data = valid_blob_data.merge("key" => existing_blob.key)

    zip = build_zip(blob_data)
    record_set = Account::DataTransfer::ActiveStorage::BlobRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::ConflictError) do
      record_set.check(from: zip)
    end

    assert_match(/already exists/, error.message)
  end

  private
    def importing_account
      @importing_account ||= Account.create!(name: "Importing Account", external_account_id: 99999999)
    end

    def valid_blob_data
      {
        "id" => "test_blob_id_000000000000000",
        "account_id" => "nonexistent_account_id_0000000",
        "key" => "abcdef1234567890abcdef1234567890",
        "filename" => "test.txt",
        "content_type" => "text/plain",
        "metadata" => "{}",
        "byte_size" => 100,
        "checksum" => "abc123==",
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def assert_path_traversal_rejected(key)
      blob_data = valid_blob_data.merge("key" => key)

      zip = build_zip(blob_data)
      record_set = Account::DataTransfer::ActiveStorage::BlobRecordSet.new(importing_account)

      error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
        record_set.check(from: zip)
      end

      assert_match(/path traversal/, error.message)
    end

    def build_zip(blob_data)
      tempfile = Tempfile.new([ "blob_import", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{blob_data['id']}.json", blob_data.to_json)
      writer.close
      tempfile.rewind

      ZipFile::Reader.new(tempfile)
    end
end
