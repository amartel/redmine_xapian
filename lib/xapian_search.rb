module XapianSearch

  @@numattach=0
  def XapianSearch.search_attachments(repository, tokens, limit_options, offset, before, projects_to_search, all_words, user_stem_lang, user_stem_strategy )
    xpattachments = Array.new
    return [xpattachments,0] unless Setting.plugin_redmine_xapian['enable'] == "true"
    return [xpattachments,0] if (repository.is_a?(Repository) and !User.current.allowed_to?(:browse_repository, repository.project))

    Rails.logger.debug "DEBUG: global settings dump" + Setting.plugin_redmine_xapian.inspect
    Rails.logger.debug "DEBUG: user_stem_lang: " + user_stem_lang.inspect
    Rails.logger.debug "DEBUG: user_stem_strategy: " + user_stem_strategy.inspect
    Rails.logger.debug "DEBUG: databasepath: " + getDatabasePath(repository, user_stem_lang)
    databasepath = getDatabasePath(repository, user_stem_lang)

    begin
      database = Xapian::Database.new(databasepath)
    rescue => error
      raise databasepath
      return [xpattachments,0]
    end

    # Start an enquire session.

    enquire = Xapian::Enquire.new(database)

    # Combine the rest of the command line arguments with spaces between
    # them, so that simple queries don't have to be quoted at the shell
    # level.
    #queryString = ARGV[1..-1].join(' ')
    queryString = tokens.join(' ')
    # Parse the query string to produce a Xapian::Query object.
    qp = Xapian::QueryParser.new()
    stemmer = Xapian::Stem.new(user_stem_lang)
    qp.stemmer = stemmer
    qp.database = database
    case @user_stem_strategy
    when "STEM_NONE" then qp.stemming_strategy = Xapian::QueryParser::STEM_NONE
    when "STEM_SOME" then qp.stemming_strategy = Xapian::QueryParser::STEM_SOME
    when "STEM_ALL" then qp.stemming_strategy = Xapian::QueryParser::STEM_ALL
    end
    if all_words
      qp.default_op = Xapian::Query::OP_AND
    else
      qp.default_op = Xapian::Query::OP_OR
    end
    query = qp.parse_query(queryString)
    Rails.logger.debug "DEBUG queryString is: #{queryString}"
    Rails.logger.debug "DEBUG: Parsed query is: #{query.description()} "

    # Find the top 100 results for the query.
    enquire.query = query
    matchset = enquire.mset(0, 1000)

    return [xpattachments,0] if matchset.nil?

    # Display the results.
    #logger.debug "#{@matchset.matches_estimated()} results found."
    Rails.logger.debug "DEBUG: Matches 1-#{matchset.size}:\n"

    nbmatches = 0
    matchset.matches.each {|m|
      #Rails.logger.debug "#{m.rank + 1}: #{m.percent}% docid=#{m.docid} [#{m.document.data}]\n"
      #logger.debug "DEBUG: m: " + m.document.data.inspect
      begin
        docdata=m.document.data{url}
        dochash=Hash[*docdata.scan(/(url|sample|modtime|type|size)=\/?([^\n\]]+)/).flatten]
        if not dochash.nil? then
          if !repository.is_a?(Repository)
            docattach=Attachment.scoped (:conditions =>  find_conditions ).first
            if not docattach.nil? then
              if docattach.visible?
                container = docattach.container
                if repository.has_key?(container.project.id)
                  nbmatches += 1
                  if ((not offset) or (before and docattach.created_on < offset) or (docattach.created_on > offset and not before))
                    title = docattach.filename
                    if !docattach.description.blank?
                      title += " (#{docattach.description})"
                    end
                    title += " [#{container.event_title}]"
                    prj = container.is_a?(Project) ? container : container.project
                    xs = XapianSearch::FileResult.new(prj, title, docattach.event_url, "CONTENT: "+dochash["sample"], docattach.author, docattach.created_on)
                    xpattachments << xs
                  end
                end
              end
            end
          else
            path = URI.unescape(dochash.fetch('url'))
            xs = XapianSearch::FileResult.new(repository.project, path, {:controller => 'repositories', :action => 'raw', :id => repository.project.identifier, :repository_id => repository.identifier, :path => path.sub(/^\//, '').split(%r{[/\\]}).select {|p| !p.blank?}}, "CONTENT: "+dochash["sample"], "", File.ctime(repository.url + "/" + path))
            Rails.logger.debug "offset: #{offset}   xs.event_datetime: #{xs.event_datetime}"
            nbmatches += 1
            if (not offset) or (before and xs.event_datetime < offset) or (xs.event_datetime > offset and not before)
              xpattachments << xs
            end
          end
        end
      rescue => error
        Rails.logger.error "Error when processing a file from xapian result set: #{error}"
      end
    }
    @@numattach=xpattachments.size
#    xpattachments=xpattachments.sort_by{|x| x.event_datetime }
    [xpattachments, nbmatches]
  end

  def XapianSearch.project_included( project_id, projects_to_search )
    return true if projects_to_search.nil?
    found=false
    projects_to_search.each {|x|
      found=true if x[:id] == project_id
    }
    found
  end

  def XapianSearch.getDatabasePath(repository, user_stem_lang)
    if !repository.is_a?(Repository)
      return Setting.plugin_redmine_xapian['index_database'].rstrip + '/' + user_stem_lang
    else
      if repository.identifier.blank?
        return Setting.plugin_redmine_xapian['index_database'].rstrip + "/#{repository.project.identifier}/" + user_stem_lang
      else
        return Setting.plugin_redmine_xapian['index_database'].rstrip + "/#{repository.project.identifier}/#{repository.identifier}/" + user_stem_lang
      end
    end
  end
end
