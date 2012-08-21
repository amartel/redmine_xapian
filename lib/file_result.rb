
module XapianSearch
  class FileResult
    attr_accessor :created_on
    
    def initialize(project, title, url, description, author, created)
      #RAILS_DEFAULT_LOGGER.info "Dans fileresource.initialize projectname= #{@project.name}"
      @proj = project
      @title = title
      @description = description
      @author = author
      @created_on = created
      @url = url
    end
    
    def project
      @proj
    end
    def event_datetime
      @created_on
    end
    def event_title
      @title
    end
    def event_description
      @description
    end
    def event_author
      @author
    end
    def event_type
      "attachment"
    end
    def event_date
      event_datetime.to_date
    end
    def event_url
      @url
    end
  end
end