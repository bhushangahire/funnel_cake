require 'spec_helper'

class UserDummy; end

describe 'when setting the engine classes' do
  it 'should use the defaults' do
    FunnelCake::Engine.user_class.should be_nil # User is not defined
    FunnelCake::Engine.visitor_class.should == Analytics::Visitor
    FunnelCake::Engine.event_class.should == Analytics::Event
  end
  it 'should set custom classes' do
    FunnelCake::Engine.user_class.should be_nil # User is not defined
    FunnelCake::Engine.user_class = UserDummy
    FunnelCake::Engine.user_class.should == UserDummy
  end
end


describe 'when finding visitors by eligibility to transition from state' do
  describe 'without a date range' do  
    before(:each) do
      @a = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @b = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
      end
      @c = create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @d = create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted
      end
    end
    it 'should return visitors who entered the state MINUS those who exited the state' do
      FunnelCake::Engine.eligible_to_transition_from_state(:a_started).should only_have_objects([ @b ])
    end
  end
  describe 'for a given date range' do
    before(:each) do
      @visitors = []
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-15), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'AAA') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-13), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'BBB') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'aaa'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'ccc'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>7), :referer=>'ddd'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted, :created_at=>build_date(:days=>-7), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-7), :referer=>'ddd'
      end
      @date_range = build_date(:days=>-14)..build_date(:days=>0)
      @opts = { :date_range=>@date_range }
    end
    it 'should return the visitors who entered the state before the end MINUS those who exited before the start' do
      FunnelCake::Engine.eligible_to_transition_from_state(:a_started, @opts).should only_have_objects([ 
        @visitors[1], @visitors[2],
      ])
    end
    describe 'with a has_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :has_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :has_event_with=>{:referer=>'bbb'} )
        ).should only_have_objects([ @visitors[1] ])
      end  
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :has_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :has_event_with=>{:referer=>/b+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with a first_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :first_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started, 
          @opts.merge( :first_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end      
    end
    describe 'with a visitor_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started,
          @opts.merge( :visitor_with=>{:key=>'AAA'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started,
          @opts.merge( :visitor_with=>{:key=>/A+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with an attrition period' do
      it 'should return the visitors' do
        FunnelCake::Engine.eligible_to_transition_from_state(:a_started,
          @opts.merge( :attrition_period=>14.days )        
        ).should only_have_objects([])
      end
    end
  end
end

describe 'when finding visitors by transition to state' do
  describe 'without a date range' do  
    before(:each) do
      @a = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @b = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
      end
      @c = create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @d = create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted
      end
    end
    it 'should return visitors who entered the state' do
      FunnelCake::Engine.transitioned_to_state(:a_started).should only_have_objects([ @a, @b ])
    end
  end
  describe 'for a given date range' do
    before(:each) do
      @visitors = []
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-15), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'AAA') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-13), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'BBB') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'aaa'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'ccc'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>7), :referer=>'ddd'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted, :created_at=>build_date(:days=>-7), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-7), :referer=>'ddd'
      end
      @date_range = build_date(:days=>-14)..build_date(:days=>0)
      @opts = { :date_range=>@date_range }
    end
    it 'should return the visitors who entered the state during the date range' do
      FunnelCake::Engine.transitioned_to_state(:b_started, @opts).should only_have_objects([ 
        @visitors[1], @visitors[6],
      ])
    end
    describe 'with a has_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :has_event_with=>{:referer=>'aaa'} )
        ).should == [ @visitors[1] ]
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :has_event_with=>{:referer=>'bbb'} )
        ).should == [ @visitors[1] ]
      end  
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :has_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :has_event_with=>{:referer=>/b+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with a first_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :first_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_to_state(:b_started, 
          @opts.merge( :first_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end      
    end
    describe 'with a visitor_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_to_state(:b_started,
          @opts.merge( :visitor_with=>{:key=>'AAA'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_to_state(:b_started,
          @opts.merge( :visitor_with=>{:key=>/A+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
  end
end

describe 'when finding visitors by transition from state' do
  describe 'without a date range' do  
    before(:each) do
      @a = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @b = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
      end
      @c = create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @d = create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted
      end
    end
    it 'should return visitors who entered the state' do
      FunnelCake::Engine.transitioned_from_state(:a_started).should only_have_objects([ @a, @c ])
    end
  end
  describe 'for a given date range' do
    before(:each) do
      @visitors = []
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-15), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'AAA') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-13), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'BBB') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'aaa'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'ccc'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>7), :referer=>'ddd'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted, :created_at=>build_date(:days=>-7), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-7), :referer=>'ddd'
      end
      @date_range = build_date(:days=>-14)..build_date(:days=>0)
      @opts = { :date_range=>@date_range }
    end
    it 'should return the visitors who exited the state during the date range' do
      FunnelCake::Engine.transitioned_from_state(:a_started, @opts).should only_have_objects([ 
        @visitors[1], @visitors[6],
      ])
    end
    describe 'with a has_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :has_event_with=>{:referer=>'bbb'} )
        ).should == [ @visitors[1] ]
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :has_event_with=>{:referer=>'aaa'} )
        ).should == [ @visitors[1] ]
      end  
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :has_event_with=>{:referer=>/b+/} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :has_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with a first_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :first_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :first_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end      
    end
    describe 'with a visitor_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :visitor_with=>{:key=>'AAA'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_from_state(:a_started,
          @opts.merge( :visitor_with=>{:key=>/A+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
  end
end

describe 'when finding visitors by transition from state to state' do
  describe 'without a date range' do  
    before(:each) do
      @a = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @b = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
      end
      @c = create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @d = create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted
      end
    end
    it 'should return visitors who transitioned between states' do
      FunnelCake::Engine.transitioned_between_states(:a_started, :b_started).should only_have_objects([ @a, @c ])
    end
  end
  describe 'for a given date range' do
    before(:each) do
      @visitors = []
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-15), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'AAA') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-13), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'BBB') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'aaa'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'ccc'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>7), :referer=>'ddd'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted, :created_at=>build_date(:days=>-7), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-7), :referer=>'ddd'
      end
      @date_range = build_date(:days=>-14)..build_date(:days=>0)
      @opts = { :date_range=>@date_range }
    end
    it 'should return the visitors who exited the start state and entered the end state during the date range' do
      FunnelCake::Engine.transitioned_between_states(:a_started, :b_started, @opts).should only_have_objects([ 
        @visitors[1], @visitors[6],
      ])
    end
    describe 'with states in between' do
      it 'should return the visitors who exited the start state and entered the end state during the date range' do
        @opts = { :date_range=>build_date(:days=>-31)..build_date(:days=>0) }
        FunnelCake::Engine.transitioned_between_states(:page_visited, :b_started, @opts).should only_have_objects([ 
          @visitors[0], @visitors[1],
        ])
      end
    end
    describe 'with a has_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>'bbb'} )
        ).should == [ @visitors[1] ]
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>'aaa'} )
        ).should == [ @visitors[1] ]
      end  
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>/b+/} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with a first_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :first_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :first_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end      
    end
    describe 'with a visitor_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :visitor_with=>{:key=>'AAA'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_between_states(:a_started, :b_started,
          @opts.merge( :visitor_with=>{:key=>/A+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
  end
end

describe 'when finding visitors by transition directly from state to state' do
  describe 'without a date range' do  
    before(:each) do
      @a = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @b = create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started
      end
      @c = create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started
      end
      @d = create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted
      end
    end
    it 'should return visitors who transitioned between states' do
      FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started).should only_have_objects([ @a, @c ])
    end
  end
  describe 'for a given date range' do
    before(:each) do
      @visitors = []
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-15), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'AAA') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'aaa'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-13), :referer=>'bbb'
      end
      @visitors << create_visitor_with(:key=>'BBB') do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>-30), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'aaa'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:page_visited, :to=>:a_started, :created_at=>build_date(:days=>1), :referer=>'ccc'
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>7), :referer=>'ddd'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:unknown, :to=>:page_visted, :created_at=>build_date(:days=>-7), :referer=>'ccc'
      end
      @visitors << create_visitor_with do |v|
        create_event_for v, :from=>:a_started, :to=>:b_started, :created_at=>build_date(:days=>-7), :referer=>'ddd'
      end
      @date_range = build_date(:days=>-14)..build_date(:days=>0)
      @opts = { :date_range=>@date_range }
    end
    it 'should return the visitors who exited the start state and entered the end state during the date range' do
      FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started, @opts).should only_have_objects([ 
        @visitors[1], @visitors[6],
      ])
    end
    describe 'with states in between' do
      it 'should return no visitors' do
        @opts = { :date_range=>build_date(:days=>-31)..build_date(:days=>0) }
        FunnelCake::Engine.transitioned_directly_between_states(:page_visited, :b_started, @opts).should only_have_objects([])
      end
    end
    describe 'with a has_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>'bbb'} )
        ).should == [ @visitors[1] ]
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>'aaa'} )
        ).should == [ @visitors[1] ]
      end  
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>/b+/} )
        ).should only_have_objects([ @visitors[1] ])
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :has_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
    describe 'with a first_event_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :first_event_with=>{:referer=>'aaa'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :first_event_with=>{:referer=>/a+/} )
        ).should only_have_objects([ @visitors[1] ])
      end      
    end
    describe 'with a visitor_with filter' do
      it 'should return the visitors with an exact match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :visitor_with=>{:key=>'AAA'} )
        ).should only_have_objects([ @visitors[1] ])
      end
      it 'should return the visitors with a regex match' do
        FunnelCake::Engine.transitioned_directly_between_states(:a_started, :b_started,
          @opts.merge( :visitor_with=>{:key=>/A+/} )
        ).should only_have_objects([ @visitors[1] ])
      end
    end
  end
end



# describe "when visitor_withing funnel events", :type=>:model do
#   describe "for a given date range" do
#     before(:each) do
#       start_date = DateTime.civil(1978, 5, 12, 12, 0, 0, Rational(-5, 24))
#       end_date = DateTime.civil(1978, 5, 12, 17, 0, 0, Rational(-5, 24))
#       @date_range = start_date..end_date
#       FunnelCake::Engine.user_class = UserDummy
#       FunnelCake::Engine.visitor_class = Analytics::Visitor
#       FunnelCake::Engine.event_class = Analytics::Event
#     end
# 
#     describe "when calculating conversion rates" do
#       describe "from state A to state B" do
#         it "should be the correct rate" do
#           @rate = FunnelCake::Engine.conversion_rate(:a_started, :b_started, {:date_range=>@date_range})
#           @rate.should == (1.0/3.0)
#         end
#       end
#     end
#   end # for a given date range
# end
# 
# describe "when finding users by funnel events", :type=>:model do
#   it "should have 18 users" do
#     UserDummy.count.should == 18
#   end
# 
#   it "should have the correct number of funnel events for :before_before" do
#     users(:before_before).funnelcake_events.count.should == 3
#   end
# 
#   describe "for a given date range" do
#     before(:each) do
#       start_date = DateTime.civil(1978, 5, 12, 12, 0, 0, Rational(-5, 24))
#       end_date = DateTime.civil(1978, 5, 12, 17, 0, 0, Rational(-5, 24))
#       @date_range = start_date..end_date
#       FunnelCake::Engine.user_class = UserDummy
#       FunnelCake::Engine.visitor_class = Analytics::Visitor
#       FunnelCake::Engine.event_class = Analytics::Event
#     end
#     describe "by starting state A" do
#       before(:each) do
#         @found = FunnelCake::Engine.eligible_to_transition_from_state(:a_started, {:date_range=>@date_range})
#       end
#       it "should find the right number of users" do
#         @found.count.should == 18
#       end
#       it "should find the :before_during user" do
#         @found.include?(users(:before_during)).should be_true
#         @found.include?(users(:visitor_before_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_before_during)).should be_true
#       end
#       it "should find the :before_after user" do
#         @found.include?(users(:before_after)).should be_true
#         @found.include?(users(:visitor_before_after)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_before_after)).should be_true
#       end
#       it "should find the :during_during user" do
#         @found.include?(users(:during_during)).should be_true
#         @found.include?(users(:visitor_during_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during_during)).should be_true
#       end
#       it "should find the :during_after user" do
#         @found.include?(users(:during_after)).should be_true
#         @found.include?(users(:visitor_during_after)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during_after)).should be_true
#       end
#       it "should find the :before user" do
#         @found.include?(users(:before)).should be_true
#         @found.include?(users(:visitor_before)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_before)).should be_true
#       end
#       it "should find the :during user" do
#         @found.include?(users(:during)).should be_true
#         @found.include?(users(:visitor_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during)).should be_true
#       end
#     end
# 
#     describe "by starting state A and ending state B" do
#       before(:each) do
#         @found = FunnelCake::Engine.find_by_state_pair(:a_started, :b_started, {:date_range=>@date_range})
#       end
#       it "should find the right number users" do
#         @found.count.should == 6
#       end
#       it "should find the :before_during user" do
#         @found.include?(users(:before_during)).should be_true
#         @found.include?(users(:visitor_before_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_before_during)).should be_true
#       end
#       it "should find the :during_during user" do
#         @found.include?(users(:during_during)).should be_true
#         @found.include?(users(:visitor_during_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during_during)).should be_true
#       end
#     end
# 
#     describe "by starting state unknown and ending state B" do
#       before(:each) do
#         @found = FunnelCake::Engine.find_by_state_pair(:unknown, :b_started, {:date_range=>@date_range})
#       end
#       it "should find the right number users" do
#         @found.count.should == 3
#       end
#       it "should find the :during_during user" do
#         @found.include?(users(:during_during)).should be_true
#         @found.include?(users(:visitor_during_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during_during)).should be_true
#       end
#     end
# 
#     describe "by transition from state A to ending state B" do
#       before(:each) do
#         @found = FunnelCake::Engine.find_by_transition(:a_started, :b_started, {:date_range=>@date_range})
#       end
#       it "should find the right number users" do
#         @found.count.should == 6
#       end
#       it "should find the :before_during user" do
#         @found.include?(users(:before_during)).should be_true
#         @found.include?(users(:visitor_before_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_before_during)).should be_true
#       end
#       it "should find the :during_during user" do
#         @found.include?(users(:during_during)).should be_true
#         @found.include?(users(:visitor_during_during)).should be_true
#         @found.include?(funnelcake_visitors(:visitor_only_during_during)).should be_true
#       end
#     end
# 
#     describe "by transition unknown to ending state B" do
#       before(:each) do
#         @found = FunnelCake::Engine.find_by_transition(:unknown, :b_started, {:date_range=>@date_range})
#       end
#       it "should find the right number users" do
#         @found.count.should == 0
#       end
#     end
# 
#   end # for a given date range
# 
#   describe "by transition from unknown to ending state B" do
#     before(:each) do
#       @found = FunnelCake::Engine.find_by_transition(:unknown, :b_started)
#     end
#     it "should find the right number users" do
#       @found.count.should == 0
#     end
#   end
# 
#   describe "by starting state unknown and ending state B" do
#     before(:each) do
#       @found = FunnelCake::Engine.find_by_state_pair(:unknown, :b_started)
#     end
#     it "should find the right number of users" do
#       @found.count.should == 18
#     end
#   end
# 
# end
# 