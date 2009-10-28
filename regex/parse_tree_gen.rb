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
            nodes, node_id = get_nodes_list(tree, [])
            nodes_str = nodes.inject("") do |s, node|
                rep = node[:node].token_type == :simple ? node[:node].value : node[:node].token_type.to_s
                s + "n#{node[:id]} [label=\"#{rep}\"]\n    " 
            end
            edges_str = nodes.inject("") do |s, node| 
                if node[:node].respond_to?(:left)
                    s = s + "n#{node[:id]} -> n#{node[:node].left.id};\n    " if node[:node].left
                    s = s + "n#{node[:id]} -> n#{node[:node].right.id};\n    " if node[:node].right
                end
                s
            end
            return nodes_str, edges_str
        end

        def get_nodes_list(tree, list, node_id = 0)
            if tree
                list, node_id = get_nodes_list(tree.left, list, node_id) if tree.left
                node_id += 1
                list.push({:id => node_id, :node => tree})
                tree.id = node_id
                list, node_id = get_nodes_list(tree.right, list, node_id) if tree.right
            end
            return list, node_id
        end
    end
end
