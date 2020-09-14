FROM ruby:2.6.0
COPY . /ifg_claim_mgmt_sync
WORKDIR /ifg_claim_mgmt_sync
RUN gem install bundler:2.1.4
RUN bundle install
CMD bundle exec ruby main.rb
