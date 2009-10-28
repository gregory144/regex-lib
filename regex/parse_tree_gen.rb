require 'tempfile'

class ParseTreeGen

    TEMPLATE_FILE = "parse_tree_template.dot"

    class << self
        def read_template
            IO.readlines(TEMPLATE_FILE, '').to_s
        end

        def gen(tree, out = "parse_tree.dot")
            parse_tree = read_template
            nodes, edges = get_nodes(tree)
            parse_tree = replace(parse_tree, "$NODES;", nodes)
            parse_tree = replace(parse_tree, "$EDGES;", edges)
            puts "Parse Tree:\n#{parse_tree}"
            File.open('parse_tree.dot', "w") do |dot_file|
                dot_file.write(parse_tree)
                dot_file.flush
                #parse_tree_img = `dot -Tpng \`cygpath -a --windows #{dot_file.path}\``
                #File.open(out, 'w') {|f| f.write(parse_tree_img) }
            end
        end

        def replace(parse_tree, token, str)
            parse_tree.gsub!(token, str)
        end

        def get_nodes(tree)
            nodes = get_nodes_list(tree, [])
            nodes_str = nodes.inject("") do |s, node|
                rep = node[:node].token_type == :simple ? node[:node].value : node[:node].token_type.to_s
                s + "n#{node[:id]} [label=\"#{rep}\"]\n    " 
            end
            edges_str = nodes.inject("") do |s, node| 
                if node[:node].respond_to?(:operands)
                    node[:node].operands.each do |operand|
                    s = s + "n#{node[:id]} -> n#{operand.id};\n    " if operand
                    end
                end
                s
            end
            return nodes_str, edges_str
        end

        def get_nodes_list(tree, list)
            if tree
                list.push({:id => list.size+1, :node => tree})
                tree.id = list.size
                tree.operands.each do |operand|
                    list = get_nodes_list(operand, list)
                end
            end
            list
        end
    end
end
