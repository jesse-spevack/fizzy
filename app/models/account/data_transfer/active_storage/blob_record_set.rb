class Account::DataTransfer::ActiveStorage::BlobRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(
      account: account,
      model: ::ActiveStorage::Blob,
      attributes: ::ActiveStorage::Blob.column_names - %w[service_name]
    )
  end

  private
    def check_record(file_path)
      data = super
      key = data["key"].to_s

      if key.match?(%r{\A[./\\]})
        raise IntegrityError, "ActiveStorage::Blob key #{key.inspect} contains path traversal characters"
      end

      if ::ActiveStorage::Blob.exists?(key: key)
        raise ConflictError, "ActiveStorage::Blob with key #{key.inspect} already exists"
      end
    end

    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data.slice(*attributes).merge(
          "account_id" => account.id,
          "service_name" => ::ActiveStorage::Blob.service.name
        )
      end

      model.insert_all!(batch_data)
    end
end
