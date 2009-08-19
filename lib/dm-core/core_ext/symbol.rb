class Symbol
  (DataMapper::Query::Conditions::Comparison.slugs | [ :not, :asc, :desc ]).each do |sym|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{sym}
        #{"warn \"explicit use of '#{sym}' operator is deprecated (#{caller[0]})\"" if sym == :eql || sym == :in}
        DataMapper::Query::Operator.new(self, #{sym.inspect})
      end
    RUBY
  end
end # class Symbol
