dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

%w[ abstract in_memory data_objects sqlite3 mysql postgres ].each do |name|
  begin
    require dir / "#{name}_adapter"
  rescue LoadError
    # Ignore it
  end
end
