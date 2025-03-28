from pydub import AudioSegment
import argparse


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Convert result to ares support format binary file.")
    parser.add_argument("--input_file",
                        default="./voice/崇祯.m4a",
                        help="m4a input file path.")
    parser.add_argument("--output_file",
                        default="./output/崇祯.wav",
                        help="wav output file path.")
    args = parser.parse_args()
    AudioSegment.from_file(args.input_file, format='m4a').export(args.output_file, format='wav')
