# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::OrderedMethods, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new('Layout/OrderedMethods' => {})
  end
  let(:message) do
    'Method should be sorted in an alphabetical order within their ' \
    'section of class/module visibility. Method `%s` should appear before `%s`.'
  end

  context 'with a complete ordered example' do
    it 'does not create offense' do
      expect_no_offenses <<-RUBY
        class Person
          def self.a_method; end

          def self.b_method; end

          def initialize; end

          def a_method; end

          def b_method; end

          # concerning :EventTracking do
          #   def aaa_method; end
          #
          #   def bbb_method; end
          #
          #   private
          #     def aaaa_method; end
          #
          #     def bbbb_method; end
          # end

          private

            def aa_method; end

            def bb_method; end
        end
      RUBY
    end
  end

  context 'with `initialize` followed by `a_method`' do
    it ' does not create offense' do
      expect_no_offenses <<-RUBY
        class Person
          def initialize; end

          def a_method; end
        end
      RUBY
    end
  end

  context 'with offenses : ' do
    it 'registers 2 offenses' do
      expect_offense <<-RUBY.strip_indent
        class Person
          def self.b_method
          end

          def self.a_method
          ^^^^^^^^^^^^^^^^^ #{format(message, 'a_method', 'b_method')}
          end

          def b_method
          end

          def a_method
          ^^^^^^^^^^^^ #{format(message, 'a_method', 'b_method')}
          end
        end
      RUBY
    end

    it 'autocorrects' do
      expect(autocorrect_source_with_loop(<<-RUBY.strip_indent))
        class Person
          def self.b_method
          end

          def self.a_method
          end

          def initialize
          end

          # b desc
          def b_method
          end

          def a_method
          end

          private

          def bp_method
          end

          # ap desc
          def ap_method
          end
        end
      RUBY
        .to eq(<<-RUBY.strip_indent)
        class Person
          def self.a_method
          end

          def self.b_method
          end

          def initialize
          end

          def a_method
          end

          # b desc
          def b_method
          end

          private

          # ap desc
          def ap_method
          end

          def bp_method
          end
        end
      RUBY
    end
  end
end
