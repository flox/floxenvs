#!/usr/bin/env python3

import click
import os
import anthropic
from pathlib import Path

@click.command()
@click.option(
    "--model",
    "-m",
    default="claude-3-5-sonnet-20240620",
    help="The Claude model to use (sonnet3.5, opus3, sonnet3, haiku3, or full model name)",
    metavar="<string>",
)
@click.option(
    "--temperature",
    "-t",
    default=0.0,
    help="The temperature (0.0 to 1.0) for response generation",
    metavar="<float>",
)
@click.option(
    "--max-tokens",
    "-x",
    default=1000,
    help="The maximum number of tokens in the response",
    metavar="<integer>",
)
@click.option(
    "--infile",
    "-i",
    help="File to read input from",
    metavar="<file>",
)
@click.option(
    "--outfile",
    "-o",
    help="File to write the response to",
    metavar="<file>",
)
@click.argument("prompt")
def claude(model, temperature, max_tokens, infile, outfile, prompt):

    if model == "sonnet3.5":
        model_fullname = "claude-3-5-sonnet-20240620"
    elif model == "opus3":
        model_fullname = "claude-3-opus-20240229"
    elif model == "sonnet3":
        model_fullname = "claude-3-sonnet-20240229"
    elif model == "haiku3":
        model_fullname = "claude-3-haiku-20240307"
    else:
        model_fullname = model

    if infile:
        # try:
        size = os.path.getsize(infile)
        # except:
        #     print("Error: could not open", infile)
        #     exit(1)

        if size > 16383:
            print("Error: input file size exceeds 16kb limit.")
            exit(1)

        file_path = Path(infile)
        inputfilecontent = file_path.read_text()

        fullprompt = (inputfilecontent + " " + prompt).strip()
    else:
        fullprompt = prompt.strip()

    # try:
    client = anthropic.Anthropic()
    message = client.messages.create(
        model=model_fullname,
        max_tokens=max_tokens,
        temperature=temperature,
        messages=[{"role": "user", "content": fullprompt}],
    )
    # except anthropic.BadRequestError as ex:
    #     print(ex.body["error"]["message"])
    #     exit(1)

    content = message.content[0].text

    if outfile:
        write_file = open(outfile, "w")
        write_file.write(content)
        write_file.close()
        print("Output saved to", outfile)
    else:
        print(content)
    return


if __name__ == "__main__":
    claude(auto_envvar_prefix="CLAUDE")

