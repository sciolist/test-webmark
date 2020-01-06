FROM ruby:2.6.4
WORKDIR /app
ENV RACK_ENV production
RUN gem install bundler
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD bundle exec unicorn -o 0.0.0.0 -p 3000 -E production  -c config/unicorn.rb ./app.rb