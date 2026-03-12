"""
GDScript 缩进转换工具
将文件中的4个空格缩进转换为Tab缩进，或反向转换
支持内存还原和命令行打印
"""

import sys
import os
from pathlib import Path


def spaces_to_tabs(input_file, output_file=None):
    """
    将4个空格缩进转换为Tab缩进
    
    Args:
        input_file: 输入文件路径
        output_file: 输出文件路径（默认覆盖原文件）
    """
    input_path = Path(input_file)
    
    if not input_path.exists():
        print(f"错误: 文件 '{input_file}' 不存在")
        return False
    
    # 读取原文件（保存在内存中）
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
            original_lines = original_content.splitlines(keepends=True)
    except Exception as e:
        print(f"读取文件失败: {e}")
        return False
    
    # 转换缩进
    converted_lines = []
    for line in original_lines:
        # 计算行首的空格数
        stripped = line.lstrip(' ')
        space_count = len(line) - len(stripped)
        
        # 将4个空格转换为1个Tab
        tab_count = space_count // 4
        remaining_spaces = space_count % 4
        
        converted_line = '\t' * tab_count + ' ' * remaining_spaces + stripped
        converted_lines.append(converted_line)
    
    converted_content = ''.join(converted_lines)
    
    # 确定输出文件路径
    if output_file is None:
        output_path = input_path
    else:
        output_path = Path(output_file)
    
    # 尝试写入转换后的内容
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted_content)
        print(f"✓ 已将空格缩进转换为Tab: {output_path}")
        
        # 询问用户是否转换成功
        while True:
            response = input("\n转换是否成功？(y/n，默认y): ").strip().lower()
            if response == 'y' or response == '':
                print("转换完成！")
                return True
            elif response == 'n':
                print("正在还原原文件...")
                try:
                    with open(output_path, 'w', encoding='utf-8') as f:
                        f.write(original_content)
                    print(f"✓ 已还原原文件: {output_path}")
                except Exception as e:
                    print(f"还原失败: {e}")
                    print("\n原文件内容：")
                    print("=" * 80)
                    print(original_content)
                    print("=" * 80)
                return False
            else:
                print("请输入 y 或 n")
    
    except Exception as e:
        print(f"写入文件失败: {e}")
        print("\n无法写入文件，打印转换后的内容：")
        print("=" * 80)
        print(converted_content)
        print("=" * 80)
        print("\n原文件内容：")
        print("=" * 80)
        print(original_content)
        print("=" * 80)
        return False


def tabs_to_spaces(input_file, output_file=None):
    """
    将Tab缩进转换为4个空格缩进
    
    Args:
        input_file: 输入文件路径
        output_file: 输出文件路径（默认覆盖原文件）
    """
    input_path = Path(input_file)
    
    if not input_path.exists():
        print(f"错误: 文件 '{input_file}' 不存在")
        return False
    
    # 读取原文件（保存在内存中）
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
            original_lines = original_content.splitlines(keepends=True)
    except Exception as e:
        print(f"读取文件失败: {e}")
        return False
    
    # 转换缩进
    converted_lines = []
    for line in original_lines:
        # 将Tab转换为4个空格
        converted_line = line.replace('\t', '    ')
        converted_lines.append(converted_line)
    
    converted_content = ''.join(converted_lines)
    
    # 确定输出文件路径
    if output_file is None:
        output_path = input_path
    else:
        output_path = Path(output_file)
    
    # 尝试写入转换后的内容
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted_content)
        print(f"✓ 已将Tab缩进转换为空格: {output_path}")
        
        # 询问用户是否转换成功
        while True:
            response = input("\n转换是否成功？(y/n，默认y): ").strip().lower()
            if response == 'y' or response == '':
                print("转换完成！")
                return True
            elif response == 'n':
                print("正在还原原文件...")
                try:
                    with open(output_path, 'w', encoding='utf-8') as f:
                        f.write(original_content)
                    print(f"✓ 已还原原文件: {output_path}")
                except Exception as e:
                    print(f"还原失败: {e}")
                    print("\n原文件内容：")
                    print("=" * 80)
                    print(original_content)
                    print("=" * 80)
                return False
            else:
                print("请输入 y 或 n")
    
    except Exception as e:
        print(f"写入文件失败: {e}")
        print("\n无法写入文件，打印转换后的内容：")
        print("=" * 80)
        print(converted_content)
        print("=" * 80)
        print("\n原文件内容：")
        print("=" * 80)
        print(original_content)
        print("=" * 80)
        return False


def preview_conversion(input_file, mode='to-tabs'):
    """
    预览转换结果，不修改文件
    
    Args:
        input_file: 输入文件路径
        mode: 转换模式 ('to-tabs' 或 'to-spaces')
    """
    input_path = Path(input_file)
    
    if not input_path.exists():
        print(f"错误: 文件 '{input_file}' 不存在")
        return False
    
    # 读取原文件
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
            original_lines = original_content.splitlines(keepends=True)
    except Exception as e:
        print(f"读取文件失败: {e}")
        return False
    
    # 转换缩进
    converted_lines = []
    if mode == 'to-tabs':
        for line in original_lines:
            stripped = line.lstrip(' ')
            space_count = len(line) - len(stripped)
            tab_count = space_count // 4
            remaining_spaces = space_count % 4
            converted_line = '\t' * tab_count + ' ' * remaining_spaces + stripped
            converted_lines.append(converted_line)
    else:  # to-spaces
        for line in original_lines:
            converted_line = line.replace('\t', '    ')
            converted_lines.append(converted_line)
    
    converted_content = ''.join(converted_lines)
    
    # 显示预览
    print("\n" + "=" * 80)
    print("原文件内容预览：")
    print("=" * 80)
    print(original_content[:500] + ("..." if len(original_content) > 500 else ""))
    
    print("\n" + "=" * 80)
    print("转换后内容预览：")
    print("=" * 80)
    print(converted_content[:500] + ("..." if len(converted_content) > 500 else ""))
    print("=" * 80)
    
    return True


def main():
    """主函数"""
    # 如果没有提供文件参数，询问用户
    if len(sys.argv) < 2:
        print("GDScript 缩进转换工具")
        print("=" * 80)
        input_file = input("\n请输入要转换的文件路径: ").strip()
        
        # 移除可能存在的引号
        if input_file.startswith('"') and input_file.endswith('"'):
            input_file = input_file[1:-1]
        elif input_file.startswith("'") and input_file.endswith("'"):
            input_file = input_file[1:-1]
        
        if not input_file:
            print("错误: 未指定文件路径")
            sys.exit(1)
        
        # 检查文件是否存在
        if not Path(input_file).exists():
            print(f"错误: 文件 '{input_file}' 不存在")
            sys.exit(1)
        
        # 询问转换模式
        print("\n请选择转换模式:")
        print("  1. 将4个空格转换为Tab（默认）")
        print("  2. 将Tab转换为4个空格")
        print("  3. 仅预览转换结果")
        
        mode_choice = input("\n请输入选项 (1/2/3, 默认为1): ").strip()
        
        if mode_choice == '2':
            mode = 'to-spaces'
            preview_only = False
        elif mode_choice == '3':
            mode = 'to-tabs'
            preview_only = True
        else:
            mode = 'to-tabs'
            preview_only = False
        
        output_file = None
        
    else:
        # 使用命令行参数
        input_file = sys.argv[1]
        mode = 'to-tabs'  # 默认模式
        output_file = None
        preview_only = False
        
        # 解析参数
        i = 2
        while i < len(sys.argv):
            arg = sys.argv[i]
            if arg in ['-t', '--to-tabs']:
                mode = 'to-tabs'
            elif arg in ['-s', '--to-spaces']:
                mode = 'to-spaces'
            elif arg in ['-p', '--preview']:
                preview_only = True
            elif arg in ['-o', '--output']:
                if i + 1 < len(sys.argv):
                    output_file = sys.argv[i + 1]
                    i += 1
                else:
                    print("错误: -o 选项需要指定输出文件")
                    sys.exit(1)
            else:
                print(f"未知选项: {arg}")
                sys.exit(1)
            i += 1
    
    # 执行转换或预览
    if preview_only:
        preview_conversion(input_file, mode)
    else:
        if mode == 'to-tabs':
            spaces_to_tabs(input_file, output_file)
        elif mode == 'to-spaces':
            tabs_to_spaces(input_file, output_file)


if __name__ == '__main__':
    main()
