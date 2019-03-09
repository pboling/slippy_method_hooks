RSpec.describe SlippyMethodHooks do
  include TestHelpers

  it 'has a version number' do
    expect(SlippyMethodHooks::VERSION).not_to be nil
  end

  context 'when .time_box_method is used' do

    it 'it does not let the method exceed a given time limit' do
      timeout_time = 0.5
      klass = Class.new do
        include SlippyMethodHooks
        def meth
          sleep 1
        end
        time_box_method(timeout_time, :meth)
      end
      start_time = Time.now
      begin
        klass.new.meth
      rescue
        end_time = Time.now
      end
      result = end_time - start_time
      expect(result.round(1)).to eq(timeout_time)
    end

    context 'without a block and the method call expires' do

      before(:each) do
        test_class = Class.new do
          include SlippyMethodHooks
          def meth
            sleep 0.2
          end
          time_box_method(0.1, :meth)
        end

        @result =
          begin
            test_class.new.meth
          rescue StandardError => e
            e
          end
      end

      it "throws #{SlippyMethodHooks::TimeoutError} error" do
        expect(@result).to(be_a(SlippyMethodHooks::TimeoutError))
      end
    end

    context 'with a block and the method call expires' do

      before(:each) do
        expected_result = 'expected-result'
        @expected_result = expected_result

        test_class = Class.new do
          include SlippyMethodHooks

          attr_reader :args

          def meth
            sleep 0.2
          end

          time_box_method(0.1, :meth) do |*args|
            @args = args
            expected_result
          end
        end

        @test_obj = test_class.new
        @result =
          begin
            @test_obj.meth
          rescue StandardError => e
            e
          end
      end

      it 'returns the result of the given block' do
        expect(@expected_result).to eq(@result)
      end

      it 'yields an array of argument errors' do
        args = @test_obj.args
        expect(args).to be_a(Array)
        expect(args[0]).to eq(SlippyMethodHooks::TimeoutError)
        expect(args[1]).to be_a(String)
        expect(args[2]).to be_a(Array)
      end
    end

    context 'with a block and the method does not expire' do
      before(:each) do
        test_class = Class.new do
          include SlippyMethodHooks

          def self.expected_result
            'expected-result'
          end

          attr_reader :args

          def meth
            sleep 0.1
            self.class.expected_result
          end

          time_box_method(0.2, :meth) do |*args|
            @args = args
            raise 'bad'
          end
        end

        @test_obj = test_class.new
        @result =
          begin
            @test_obj.meth
          rescue StandardError => e
            e
          end
      end

      it 'returns the result of the method' do
        expect(@result).to eq(@test_obj.class.expected_result)
      end
    end
    context 'when .rescue_on_fail is called' do

      context 'when no block is provided' do

        before(:each) do
          @result =
            begin
              Class.new do
                include SlippyMethodHooks

                def meth; end

                rescue_on_fail(:meth)
              end
            rescue SlippyMethodHooks::NoBlockGiven => e
              e
            end
        end

        it "raises #{SlippyMethodHooks::NoBlockGiven}" do
          expect(@result).to be_a(SlippyMethodHooks::NoBlockGiven)
        end
      end

      context 'when the method fails' do
        blk = ->(err = nil) { { test_value: 'test', error: err } }

        before(:each) do
          @test_class =
            Class.new do
              include SlippyMethodHooks

              def meth
                raise StandardError, 'fart sound'
              end

              rescue_on_fail(:meth, &blk)
            end
        end

        it 'returns the result of the block' do
          result = @test_class.new.meth
          expected = blk.call
          expect(result[:test_value]).to eq(expected[:test_value])
        end

        it 'yields an error object' do
          result = @test_class.new.meth
          expect(result[:error]).to be_a(StandardError)
        end
      end
    end
  end
end
