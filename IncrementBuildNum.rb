def get_file_as_string(filename)
    data = ''
    f = File.open(filename, "r") 
    f.each_line do |line|
        data += line
    end
    return data
end


def handle_alpha_beta(old_value, letter, infoplist, start_of_value, end_of_value)
    parts = old_value.split(letter)
    version_num = parts[0]
    alpha_num = parts[1].to_i

    alpha_num = alpha_num + 1
    new_version = version_num.to_s + letter + alpha_num.to_s
    print "Assigning new version: " + new_version + "\n"
    new_key = "<string>#{new_version}</string>"

    part_1 = infoplist[0, start_of_value - '<string>'.length];
    part_2 = new_key 
    part_3 = infoplist[end_of_value + "</string>".length, infoplist.length - (end_of_value - start_of_value + (new_key.length - 1))]    

    new_info_plist = part_1 + part_2 + part_3
    new_info_plist
end

def find_and_increment_version_number_with_key(key, infoplist)

    start_of_key = infoplist.index(key)
    start_of_value = infoplist.index("<string>", start_of_key) + "<string>".length
    end_of_value = infoplist.index("</string>", start_of_value)
    old_value = infoplist[start_of_value, end_of_value - start_of_value]

    print "Old version for " + key + ": " + old_value + "\n"
    print old_value.class.to_s + "\n"
    old_value_int = old_value.to_i
    print old_value_int.class.to_s + "\n"
    if (old_value.index("a") != nil) # alpha
        infoplist = handle_alpha_beta(old_value, "a", infoplist, start_of_value, end_of_value)
    elsif (old_value.index("b") != nil) # beta
        infoplist = handle_alpha_beta(old_value, "b", infoplist, start_of_value, end_of_value)
    elsif (old_value.index(".") != nil) # release dot version
        parts = old_value.split(".")
        last_part = parts.last.to_i
        last_part = last_part + 1
        parts.delete(parts.last)

        new_version = ""
        first = true
        parts.each do |one_part|
            if (first)
                first = false
            else
                new_version = new_version + "."
            end
            new_version = new_version + one_part
        end
        new_version = new_version.to_s + "." + last_part.to_s
        print "New version: " + new_version.to_s + "\n"
        new_key = "<string>#{new_version}</string>"
        infoplist = "#{infoplist[0, start_of_value - '<string>'.length]}#{new_key}#{infoplist[end_of_value + '</string>'.length, infoplist.length - (end_of_value+1)]}"
    elsif (old_value.to_i != nil) # straight integer build number
        new_version = old_value.to_i + 1
        print "New version: " + new_version.to_s + "\n"
        new_key = "<string>#{new_version}</string>"

        part_1 = infoplist[0, start_of_value - '<string>'.length]
        part_2 = new_key
        part_3 = infoplist[end_of_value + "</string>".length, infoplist.length - (end_of_value+1)]
        infoplist = part_1 + part_2 + part_3
    end 
    infoplist
end



config = ENV['CONFIGURATION'].upcase
config_build_dir = ENV['CONFIGURATION_BUILD_DIR']

archive_action = false
if (config_build_dir.include?("ArchiveIntermediates"))
    archive_action = true
end

print "Archive: " + archive_action.to_s + "\n"


print config

if (config == "RELEASE")
    print " incrementing build numbers\n"
    project_dir = ENV['PROJECT_DIR']
    infoplist_file = ENV['INFOPLIST_FILE']
    plist_filename = "#{project_dir}/#{infoplist_file}"

    infoplist = get_file_as_string(plist_filename)
    infoplist = find_and_increment_version_number_with_key("CFBundleVersion", infoplist)
    if (archive_action)
        infoplist = find_and_increment_version_number_with_key("CFBundleShortVersionString", infoplist)
    end
    File.open(plist_filename, 'w') {|f| f.write(infoplist) }
else
    print " not incrementing build numbers"
end