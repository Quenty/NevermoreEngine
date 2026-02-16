export interface RojoTreeNode {
  $className?: string;
  $path?: string;
  $properties?: Record<string, unknown>;
  [key: string]: RojoTreeNode | string | Record<string, unknown> | undefined;
}

export interface RojoProject {
  name: string;
  tree: RojoTreeNode;
}
