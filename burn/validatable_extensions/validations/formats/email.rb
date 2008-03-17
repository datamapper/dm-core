module Validatable
  module Helpers #:nodoc:
    module Formats #:nodoc:
      
      # Allows you to validate fields as email addresses
      #   validates_format_of :email_field, :with => :email_address

      module Email
          
          def self.included(base)
            base::FORMATS.merge!( :email_address => [ EmailAddress, 
                                  lambda { |attribute| lambda { "%s is not a valid email address".t(self.send(attribute)) } }] )
          end
          
          EmailAddress = begin
            alpha = "a-zA-Z"
            digit = "0-9"
            atext = "[#{alpha}#{digit}\!\#\$\%\&\'\*+\/\=\?\^\_\`\{\|\}\~\-]"
            dot_atom_text = "#{atext}+([.]#{atext}*)*"
            dot_atom = "#{dot_atom_text}"
            qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
            text = "[\\x01-\\x09\\x11\\x12\\x14-\\x7f]"
            quoted_pair = "(\\x5c#{text})"
            qcontent = "(?:#{qtext}|#{quoted_pair})"
            quoted_string = "[\"]#{qcontent}+[\"]"
            atom = "#{atext}+"
            word = "(?:#{atom}|#{quoted_string})"
            obs_local_part = "#{word}([.]#{word})*"
            local_part = "(?:#{dot_atom}|#{quoted_string}|#{obs_local_part})"
            no_ws_ctl = "\\x01-\\x08\\x11\\x12\\x14-\\x1f\\x7f"    
            dtext = "[#{no_ws_ctl}\\x21-\\x5a\\x5e-\\x7e]"
            dcontent = "(?:#{dtext}|#{quoted_pair})"
            domain_literal = "\\[#{dcontent}+\\]"
            obs_domain = "#{atom}([.]#{atom})*"
            domain = "(?:#{dot_atom}|#{domain_literal}|#{obs_domain})"
            addr_spec = "#{local_part}\@#{domain}"
            pattern = /^#{addr_spec}$/
          end
          
      end
    end
  end
end
