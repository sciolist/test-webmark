FROM ruby:2.6.4
ENV RACK_ENV production
RUN gem install bundler
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY . .
CMD unicorn -o 0.0.0.0 -p 3000 -E production  -c config/unicorn.rb ./app.rb