FROM ruby:2.6.4
ENV RACK_ENV production
RUN gem install bundler
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY . .
CMD ruby app.rb
